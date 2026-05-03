import 'dart:convert';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:my_vibe_flick/screens/text_edit_bottom_sheet.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../Notification/audio_picker.dart';
import '../VideoEditing/Subtitle/subtitle_bottom_sheet.dart';
import '../VideoEditing/effect_bottom_sheet.dart';
import '../VideoEditing/filter_bottom_sheet.dart';
import '../VideoEditing/recorder_bottom_sheet.dart';
import '../VideoEditing/video_edit_bottom_sheet.dart';
import 'activity_post.dart';
import 'trim_bottom_sheet.dart';
import 'media_fragment.dart'; // MeadiaFragment bottom sheet show කරන්න

class SelectedMediaScreen extends StatefulWidget {
  final String mediaPath;
  final bool isVideo;
  final List<String> extraMediaPaths;
  final List<bool> extraMediaIsVideo;
  final List<double>? initialFilterMatrix; // ← camera filter pass කරන්න
  // ── Draft restore fields ──────────────────────────────────────
  final List<Map<String, dynamic>> restoredPlacedStickers;
  final List<Map<String, dynamic>> restoredTextOverlays;
  final List<Map<String, dynamic>> restoredEffectLayers;
  final double restoredTrimStart;
  final double restoredTrimEnd;
  final String restoredAspectRatio;
  final double restoredOriginalAudioVolume;
  final bool restoredIsOriginalAudioMuted;
  final String? restoredMusicTitle;
  final double restoredMusicVolume;

  const SelectedMediaScreen({
    super.key,
    required this.mediaPath,
    required this.isVideo,
    this.extraMediaPaths = const [],
    this.extraMediaIsVideo = const [],
    this.initialFilterMatrix,             // ← අලුතින් add
    // ── Draft restore fields ──────────────────────────
    this.restoredPlacedStickers = const [],
    this.restoredTextOverlays = const [],
    this.restoredEffectLayers = const [],
    this.restoredTrimStart = 0.0,
    this.restoredTrimEnd = 1.0,
    this.restoredAspectRatio = '9:16',
    this.restoredOriginalAudioVolume = 1.0,
    this.restoredIsOriginalAudioMuted = false,
    this.restoredMusicTitle,
    this.restoredMusicVolume = 0.5,
  });

  @override
  State<SelectedMediaScreen> createState() => _SelectedMediaScreenState();
}

class _SelectedMediaScreenState extends State<SelectedMediaScreen> {
  VideoPlayerController? _videoController;
  bool isPlaying = false;
  String selectedSong = 'Tu Sanam B';
  bool showSongTitle = true;
  String? _selectedMusicUrl;     // actual playable URL
  String? _selectedMusicId;      // audio ID
  String? _selectedMusicAlbumArt;


  // ── Editing state ─────────────────────────────────────────────────────────
  List<EffectLayer> _effectLayers = [];
  String? _selectedMusic;

  double _originalAudioVolume = 1.0;
  double _musicVolume = 0.5;
  bool _isOriginalAudioMuted = false;
  double _trimStart = 0.0;
  double _trimEnd = 1.0;
  String? _selectedFilter;
  List<double>? _activeFilterMatrix;
  List<RichTextOverlay> _textOverlays = [];
  OverlayEntry? _discardPopup;
  String? _editedMediaPath; // ← brush bake කළාට පස්සේ new path
  // Image editing
  Map<int, String?> _individualImageFilters = {};
  String? _globalImageFilter;
  List<String> _imageStickers = [];
  String _aspectRatio = '9:16';
  String _backgroundFillMode = 'blur';
// existing _selectedMusic ට පස්සේ add:
     // actual audio URL/path
  AudioPlayer? _imageAudioPlayer;
  // Sticker state
  List<Map<String, dynamic>> _placedStickers = [];
  int? _selectedStickerIndex;

// ── Drawing / Brush state ─────────────────────────────────────────────────
  bool _isBrushMode = false;
  List<_DrawPath> _drawPaths = [];
  List<_DrawPath> _redoPaths = [];
  Color _brushColor = Colors.white;
  double _brushSize = 6.0;
  _DrawPath? _currentPath;

  static const List<Color> _brushColors = [
    Colors.white,
    Color(0xFFD63B6E), // crimson
    Color(0xFFFF7A30), // orange
    Color(0xFFFF3EAD), // hot pink
    Color(0xFFFFD234), // yellow
    Color(0xFF7ED321), // green
    Color(0xFF4FC3F7), // sky blue
    Color(0xFF9B59FF), // purple
    Color(0xFF3B82F6), // blue
  ];

  // ── Multi-media state (add/remove logic) ─────────────────────────────────
  // Current file path list — starts with the initial mediaPath
  late List<String> _mediaPaths;
  late List<bool> _mediaIsVideo;

  // Thumbnail cache for the bottom strip (AssetEntity id → bytes)
  final Map<String, Uint8List?> _thumbnailCache = {};

  static const _stickerCategories = {
    '🔥 Trending': ['🔥', '💯', '✨', '🎯', '👀', '💥', '🤩', '🫶'],
    '❤️ Love': ['❤️', '🥰', '😍', '💕', '💖', '💘', '🩷', '😘'],
    '🎉 Party': ['🎉', '🎊', '🥳', '🍾', '🎈', '🪅', '🎆', '🕺'],
    '😎 Vibe': ['😎', '🤙', '🫡', '💅', '🧊', '🫧', '🌊', '⚡'],
  };
  String _activeStickerCategory = '🔥 Trending';

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _mediaPaths = [widget.mediaPath, ...widget.extraMediaPaths];
    _mediaIsVideo = [widget.isVideo, ...widget.extraMediaIsVideo];

    if (widget.initialFilterMatrix != null) {
      _activeFilterMatrix = widget.initialFilterMatrix;
    }

    // ── Draft restore ────────────────────────────────────────────
    if (widget.restoredPlacedStickers.isNotEmpty) {
      _placedStickers = List.from(widget.restoredPlacedStickers);
    }

    if (widget.restoredTextOverlays.isNotEmpty) {
      _textOverlays = widget.restoredTextOverlays.map((e) {
        return RichTextOverlay(
          text: e['text'] as String,
          x: (e['x'] as num).toDouble(),
          y: (e['y'] as num).toDouble(),
          fontSize: (e['fontSize'] as num).toDouble(),
          textColor: Color((e['textColor'] as int?) ?? Colors.white.value),
          bgColor: Color((e['bgColor'] as int?) ?? Colors.transparent.value),
          bgStyle: TextBgStyle.values[(e['bgStyle'] as int?) ?? 0],
          align: TextAlignOption.values[(e['align'] as int?) ?? 1],
          letterSpacing: (e['letterSpacing'] as num?)?.toDouble() ?? 0,
          lineHeight: (e['lineHeight'] as num?)?.toDouble() ?? 1.3,
          fontWeight: FontWeight.values[(e['fontWeight'] as int?) ?? 3],
          fontStyle: FontStyle.values[(e['fontStyle'] as int?) ?? 0],
          fontFamily: (e['fontFamily'] as String?) ?? '',
          neon: (e['neon'] as bool?) ?? false,
          outline: (e['outline'] as bool?) ?? false,
          outlineColor: Color((e['outlineColor'] as int?) ?? Colors.black.value),
          animation: TextAnimation.values[(e['animation'] as int?) ?? 0],
          startTime: (e['startTime'] as num?)?.toDouble() ?? 0,
          endTime: (e['endTime'] as num?)?.toDouble() ?? 10,
        );
      }).toList();
    }
    if (widget.restoredEffectLayers.isNotEmpty) {
      _effectLayers = widget.restoredEffectLayers
          .map((e) => EffectLayer(
        id: (e['id'] as String?) ?? '${e['effectKey']}_restored',
        effectKey: e['effectKey'] as String,
        intensity: (e['intensity'] as num).toDouble(),
        startSec: (e['startSec'] as num).toDouble(),
        endSec: (e['endSec'] as num).toDouble(),
      ))
          .toList();
    }
    _trimStart = widget.restoredTrimStart;
    _trimEnd = widget.restoredTrimEnd;
    _aspectRatio = widget.restoredAspectRatio;
    _originalAudioVolume = widget.restoredOriginalAudioVolume;
    _isOriginalAudioMuted = widget.restoredIsOriginalAudioMuted;
    _musicVolume = widget.restoredMusicVolume;

    if (widget.restoredMusicTitle != null) {
      _selectedMusic = widget.restoredMusicTitle;
      showSongTitle = true;
    }
    // ── End draft restore ────────────────────────────────────────

    if (widget.isVideo) {
      _initializeVideo();
    }
  }

  void _showDiscardOrSaveDraftSheet() {
    // දැනටමත් open නම් close කරන්න
    if (_discardPopup != null) {
      _discardPopup!.remove();
      _discardPopup = null;
      return;
    }

    _discardPopup = OverlayEntry(
      builder: (context) =>
          Stack(
            children: [
              // ── Background tap = close ──
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    _discardPopup?.remove();
                    _discardPopup = null;
                  },
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox.expand(),
                ),
              ),

              // ── Popup card (back button ගාව) ──
              Positioned(
                top: 90, // back button යටින් පෙනෙන්න
                left: 12,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Discard ──
                        InkWell(
                          onTap: () {
                            _discardPopup?.remove();
                            _discardPopup = null;
                            _confirmDiscard();
                          },
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            child: Row(
                              children: const [
                                Icon(Icons.close,
                                    color: Colors.black87, size: 22),
                                SizedBox(width: 16),
                                Text(
                                  'Discard',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Divider(height: 1, color: Color(0xFFEEEEEE)),

                        // ── Save Draft ──
                        InkWell(
                          onTap: () {
                            _discardPopup?.remove();
                            _discardPopup = null;
                            _saveDraft();
                          },
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            child: Row(
                              children: const [
                                Icon(Icons.inbox_outlined,
                                    color: Colors.black87, size: 22),
                                SizedBox(width: 16),
                                Text(
                                  'Save draft',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
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
              ),
            ],
          ),
    );

    Overlay.of(context).insert(_discardPopup!);
  }

  void _confirmDiscard() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Discard changes?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'All changes will be lost.',
          style: TextStyle(color: Colors.white54),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.white24),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      final file = File(widget.mediaPath);
                      if (await file.exists()) {
                        await file.delete();
                        debugPrint('🗑️ Temp video deleted');
                      }
                    } catch (e) {
                      debugPrint('⚠️ Delete error: $e');
                    }
                    if (mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFFFF3B5C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Discard',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveDraft() async {
    try {
      // ── Drafts folder create ──
      final appDir = await getApplicationDocumentsDirectory();
      final draftsDir = Directory('${appDir.path}/drafts');
      if (!await draftsDir.exists()) {
        await draftsDir.create(recursive: true);
      }

      // ── File move: temp → drafts ──
      final fileName =
          'draft_${DateTime
          .now()
          .millisecondsSinceEpoch}.mp4';
      final draftPath = '${draftsDir.path}/$fileName';

      final tempFile = File(widget.mediaPath);
      if (await tempFile.exists()) {
        await tempFile.copy(draftPath);
        // 🆕 App private folder (temp) නම් delete, නැත්නම් skip
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final tempDir = await getTemporaryDirectory();
          final filePath = widget.mediaPath;
          final isAppFile = filePath.startsWith(appDir.path) ||
              filePath.startsWith(tempDir.path);
          if (isAppFile) {
            await tempFile.delete();
            debugPrint('🗑️ Temp file deleted');
          } else {
            debugPrint('⚠️ External file - skip delete (no permission)');
          }
        } catch (e) {
          debugPrint('⚠️ Delete skip: $e');
        }
        debugPrint('💾 Draft saved: $draftPath');
      }

      // ── SharedPreferences එකේ save ──
      final prefs = await SharedPreferences.getInstance();
      final draftsJson = prefs.getString('saved_drafts') ?? '[]';
      final List<dynamic> draftsList = json.decode(draftsJson);
     // ── Generate thumbnail before saving ──
      String? thumbPath;
      if (widget.isVideo) {
        try {
          thumbPath = await VideoThumbnail.thumbnailFile(
            video: draftPath,
            thumbnailPath: draftsDir.path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 400,
            quality: 75,
            timeMs: 0,
          );
        } catch (e) {
          debugPrint('⚠️ Thumb gen error: $e');
        }
      }

// ── Get video duration ──
      int durationSec = 0;
      if (widget.isVideo && _videoController != null) {
        durationSec = _videoController!.value.duration.inSeconds;
      }

      draftsList.add({
        'path': draftPath,
        'isVideo': widget.isVideo,
        'timestamp': DateTime.now().toIso8601String(),
        'music': _selectedMusic,
        'thumbnailPath': thumbPath,
        'durationSeconds': durationSec,
        'musicStartSec': 0.0,
        'musicVolume': _musicVolume,
        // ── Editing state ──────────────────────────
        'activeFilterMatrix': _activeFilterMatrix,
        'placedStickers': _placedStickers,
        'textOverlays': _textOverlays.map((o) => {
          'text': o.text,
          'x': o.x,
          'y': o.y,
          'fontSize': o.fontSize,
          'textColor': o.textColor.value,
          'bgColor': o.bgColor.value,
          'bgStyle': o.bgStyle.index,
          'align': o.align.index,
          'letterSpacing': o.letterSpacing,
          'lineHeight': o.lineHeight,
          'fontWeight': o.fontWeight.index,
          'fontStyle': o.fontStyle.index,
          'fontFamily': o.fontFamily,
          'neon': o.neon,
          'outline': o.outline,
          'outlineColor': o.outlineColor.value,
          'animation': o.animation.index,
          'startTime': o.startTime,
          'endTime': o.endTime,
        }).toList(),
        'effectLayers': _effectLayers.map((e) => {
          'id': e.id,
          'effectKey': e.effectKey,
          'intensity': e.intensity,
          'startSec': e.startSec,
          'endSec': e.endSec,
        }).toList(),
        'trimStart': _trimStart,
        'trimEnd': _trimEnd,
        'aspectRatio': _aspectRatio,
        'originalAudioVolume': _originalAudioVolume,
        'isOriginalAudioMuted': _isOriginalAudioMuted,
        'allMediaPaths': _mediaPaths,
        'allMediaIsVideo': _mediaIsVideo,
      });
      await prefs.setString('saved_drafts', json.encode(draftsList));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Draft saved! You can edit it later'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate back
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context)
                .popUntil((route) => route.isFirst);
          }
        });
      }
    } catch (e) {
      debugPrint('⚠️ Save draft error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Draft save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.file(
      File(widget.mediaPath),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true, // Audio conflict නෑ
      ),
    );

    // Initialize + first frame show කරන්න
    await _videoController!.initialize();

    if (mounted) {
      setState(() {
        isPlaying = true;
      });
      // Initialize වෙනවාත් සමගම play
      await _videoController!.play();
      _videoController!.setLooping(true);
    }
  }

  @override
  void dispose() {
    _discardPopup?.remove(); // ← මේ line add කරන්න
    _videoController?.dispose();
    _stopImageAudioPreview(); // ✅
    super.dispose();
  }

  // ── Add / Remove Media Logic (from SelectedMediaScreen doc4) ──────────────

  bool _canAddMore() {
    if (_mediaPaths.isEmpty) return true;
    final hasVideo = _mediaIsVideo.contains(true);
    if (hasVideo) return false;
    return _mediaPaths.length < 3;
  }

  int _getMaxLimit() {
    final hasVideo = _mediaIsVideo.contains(true);
    return hasVideo ? 1 : 3;
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaPaths.removeAt(index);
      _mediaIsVideo.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('මාධ්‍යය ඉවත් කරන ලදී'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Opens the MeadiaFragment bottom sheet and appends selected media
  Future<void> _addMoreMedia() async {
    final AssetEntity? picked = await showModalBottomSheet<AssetEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MediaPickerSingleSheet(),
    );

    if (picked == null) return;

    final file = await picked.file;
    if (file == null) return;

    final isVid = picked.type == AssetType.video;

    // Validation — mirror MediaPickerScreen rules
    if (isVid && _mediaPaths.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video තෝරාගෙන ඇති විට images දැමිය නොහැක'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!isVid && _mediaIsVideo.contains(true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video සමඟ image දැමිය නොහැක'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!isVid && _mediaPaths.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('උපරිම images 3ක් පමණි'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _mediaPaths.add(file.path);
      _mediaIsVideo.add(isVid);
    });
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _navigateToPost() {
    _stopImageAudioPreview();
    // DEBUG - මේ log බලන්න
    debugPrint('🎵 Navigating to post:');
    debugPrint('   selectedMusicUrl: $_selectedMusicUrl');
    debugPrint('   selectedMusicId: $_selectedMusicId');
    debugPrint('   selectedMusic: $_selectedMusic');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostActivity(
          mediaFile: File(_editedMediaPath ?? widget.mediaPath),
          isVideo: widget.isVideo,
          mediaPath: _editedMediaPath ?? widget.mediaPath,
          allMediaPaths: _mediaPaths,
          allMediaIsVideo: _mediaIsVideo,
          activeFilterMatrix: _activeFilterMatrix,
          placedStickers: List.from(_placedStickers),
          textOverlays: List.from(_textOverlays),
          selectedMusicPath: _selectedMusicUrl,    // ✅ URL, title නෙමෙයි
          selectedMusicId: _selectedMusicId,        // ✅ ID
          selectedMusicName: _selectedMusic,         // ✅ title
          selectedMusicAlbumArt: null,
          originalAudioVolume: _isOriginalAudioMuted ? 0.0 : _originalAudioVolume,
          musicVolume: _musicVolume,
          effectLayers: List.from(_effectLayers),
          trimStart: _trimStart,
          trimEnd: _trimEnd,
          aspectRatio: _aspectRatio,
        ),
      ),
    );
  }


  Future<void> _playImageAudioPreview(String? url) async {
    if (url == null || url.isEmpty || widget.isVideo) return;
    try {
      await _stopImageAudioPreview();
      _imageAudioPlayer = AudioPlayer();
      await _imageAudioPlayer!.setVolume(_musicVolume);

      if (url.startsWith('http')) {
        await _imageAudioPlayer!.play(UrlSource(url));
      } else {
        await _imageAudioPlayer!.play(DeviceFileSource(url));
      }
      await _imageAudioPlayer!.setReleaseMode(ReleaseMode.loop);
      debugPrint('🎵 Image audio preview: $url');
    } catch (e) {
      debugPrint('❌ Audio preview error: $e');
    }
  }

  Future<void> _stopImageAudioPreview() async {
    try {
      await _imageAudioPlayer?.stop();
      await _imageAudioPlayer?.dispose();
      _imageAudioPlayer = null;
    } catch (_) {}
  }


  void _openEditBottomSheet() {
    _videoController?.pause();
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.black,
      isDismissible: false,
      enableDrag: false,
      builder: (_) =>
          VideoEditBottomSheet(
            mediaFile: File(widget.mediaPath),
            isVideo: widget.isVideo,
          ),
    ).then((_) {
      _videoController?.play();
      setState(() => isPlaying = true);
    });
  }

  void _openSubtitleBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          SubtitleBottomSheet(
            mediaFile: File(widget.mediaPath),
            isVideo: widget.isVideo,
          ),
    );
  }

  void _openRecorderBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          RecorderBottomSheet(
            mediaFile: File(widget.mediaPath),
            isVideo: widget.isVideo,
          ),
    );
  }

  void _openFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) =>
          FilterBottomSheet(
            mediaFile: File(widget.mediaPath),
            isVideo: widget.isVideo,
            onPreviewChanged: (matrix) {
              setState(() => _activeFilterMatrix = matrix);
            },
          ),
    ).then((result) {
      if (!mounted) return;
      if (result == null) {
        setState(() => _activeFilterMatrix = null);
      } else {
        final matrix = result['matrix'] as List<double>?;
        setState(() => _activeFilterMatrix = matrix);
      }
    });
  }

  void _openEnhanceBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEnhanceSheet(),
    );
  }

  void _openEffectBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          EffectBottomSheet(
            isVideo: widget.isVideo,
            videoDuration:
            _videoController?.value.duration.inSeconds.toDouble() ?? 10.0,
            initialLayers: _effectLayers,
            onDone: (layers) {
              setState(() => _effectLayers = layers);
            },
          ),
    );
  }

  // ── Music Library ─────────────────────────────────────────────────────────
  void _showMusicLibrary() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900]!.withOpacity(0.95),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'සංගීත පුස්තකාලය',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    _buildMusicItem('සුන්දර සින්දුව 1', 'තත්පර 30'),
                    _buildMusicItem('ජනප්‍රිය සින්දුව 2', 'තත්පර 45'),
                    _buildMusicItem('නව සින්දුව 3', 'තත්පර 60'),
                    _buildMusicItem('ප්‍රිය සින්දුව 4', 'තත්පර 35'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMusicItem(String title, String duration) {
    return ListTile(
      leading: const Icon(Icons.music_note, color: Colors.blue),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(duration, style: const TextStyle(color: Colors.grey)),
      onTap: () {
        setState(() => _selectedMusic = title);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title Added')),
        );
      },
    );
  }

  // ── Trim Slider ───────────────────────────────────────────────────────────
  void _showTrimSlider() {
    _videoController?.pause();
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.black,
      isDismissible: false,
      enableDrag: false,
      builder: (context) =>
          TrimBottomSheet(
            mediaFile: File(widget.mediaPath),
          ),
    ).then((result) {
      _videoController?.play();
      setState(() => isPlaying = true);
      if (result == null) return;
      final int startMs = result['startMs'] as int;
      final int endMs = result['endMs'] as int;
      final double speed = result['speed'] as double;
      final total =
          _videoController?.value.duration.inMilliseconds ?? 1;
      setState(() {
        _trimStart = startMs / total;
        _trimEnd = endMs / total;
      });
      _videoController?.setPlaybackSpeed(speed);
      _videoController?.seekTo(Duration(milliseconds: startMs));
    });
  }

  // ── Volume Controls ───────────────────────────────────────────────────────
  void _showVolumeControls() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey[900]!.withOpacity(0.95),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Sound Control',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isOriginalAudioMuted
                          ? Colors.red[900]
                          : Colors.grey[800],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: InkWell(
                      onTap: () {
                        setModalState(() {
                          _isOriginalAudioMuted = !_isOriginalAudioMuted;
                          if (_isOriginalAudioMuted) {
                            _videoController?.setVolume(0);
                          } else {
                            _videoController?.setVolume(_originalAudioVolume);
                          }
                        });
                        setState(() {});
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isOriginalAudioMuted
                                ? Icons.volume_off
                                : Icons.volume_up,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isOriginalAudioMuted
                                ? 'Unmute Original Sound'
                                : 'Mute Original Sound',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text('Original Video Sound',
                      style: TextStyle(color: Colors.white)),
                  Row(
                    children: [
                      const Icon(Icons.volume_down, color: Colors.white),
                      Expanded(
                        child: Slider(
                          value: _originalAudioVolume,
                          onChanged: _isOriginalAudioMuted
                              ? null
                              : (value) {
                            setModalState(
                                    () => _originalAudioVolume = value);
                            setState(() {});
                            _videoController?.setVolume(value);
                          },
                          activeColor: _isOriginalAudioMuted
                              ? Colors.grey
                              : Colors.blue,
                          inactiveColor: Colors.grey[700],
                        ),
                      ),
                      const Icon(Icons.volume_up, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Music Volume',
                      style: TextStyle(color: Colors.white)),
                  Row(
                    children: [
                      const Icon(Icons.volume_down, color: Colors.white),
                      Expanded(
                        child: Slider(
                          value: _musicVolume,
                          onChanged: (value) {
                            setModalState(() => _musicVolume = value);
                            setState(() {});
                          },
                          activeColor: Colors.blue,
                          inactiveColor: Colors.grey[700],
                        ),
                      ),
                      const Icon(Icons.volume_up, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Original Sound: ${(_originalAudioVolume * 100)
                        .toInt()}% | Music: ${(_musicVolume * 100).toInt()}%',
                    style:
                    const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Video Filter Options ──────────────────────────────────────────────────
  void _showVideoFilterOptions() {
    final filters = [
      'None', 'Black & White', 'Sepia', 'Cool', 'Warm', 'Vintage'
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Filter',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filters.length,
                  itemBuilder: (context, index) {
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedFilter = filters[index]);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(10),
                          border: _selectedFilter == filters[index]
                              ? Border.all(color: Colors.blue, width: 2)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            filters[index],
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Text Overlay ──────────────────────────────────────────────────────────
  void _showTextOverlay() {
    final duration =
        _videoController?.value.duration.inSeconds.toDouble() ?? 10.0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          TextEditBottomSheet(
            mediaDuration: duration,
            onDone: (RichTextOverlay overlay) {
              setState(() => _textOverlays.add(overlay));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Text added!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
    );
  }

  // ── Image Filter Options ──────────────────────────────────────────────────
  void _showImageFilterOptions() {
    final filters = [
      'None', 'Black & White', 'Sepia', 'Cool', 'Warm', 'Bright', 'Dark'
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900]!.withOpacity(0.95),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Filter',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filters.length,
                  itemBuilder: (context, index) {
                    bool isSelected =
                        _individualImageFilters[0] == filters[index];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _individualImageFilters[0] = filters[index];
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${filters[index]} filter applied'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(color: Colors.blue, width: 3)
                              : null,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isSelected)
                                const Icon(Icons.check_circle,
                                    color: Colors.blue, size: 20),
                              const SizedBox(height: 5),
                              Text(
                                filters[index],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Aspect Ratio Options ──────────────────────────────────────────────────
  void _showAspectRatioOptions() {
    final ratios = [
      {
        'ratio': '9:16',
        'label': '9:16',
        'social': 'TikTok / Reels',
        'w': 9.0,
        'h': 16.0
      },
      {
        'ratio': '1:1',
        'label': '1:1',
        'social': 'Instagram Post',
        'w': 1.0,
        'h': 1.0
      },
      {
        'ratio': '16:9',
        'label': '16:9',
        'social': 'YouTube',
        'w': 16.0,
        'h': 9.0
      },
      {
        'ratio': '4:5',
        'label': '4:5',
        'social': 'IG Portrait',
        'w': 4.0,
        'h': 5.0
      },
      {
        'ratio': '3:4',
        'label': '3:4',
        'social': 'Standard Photo',
        'w': 3.0,
        'h': 4.0
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Canvas Size',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 130,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: ratios.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final item = ratios[index];
                        final bool isSelected =
                            _aspectRatio == item['ratio'];
                        final double w = item['w'] as double;
                        final double h = item['h'] as double;
                        final double boxH = 54.0;
                        final double boxW = (w / h) * boxH;
                        final double clampedW = boxW.clamp(22.0, 70.0);

                        return GestureDetector(
                          onTap: () {
                            setState(
                                    () =>
                                _aspectRatio = item['ratio'] as String);
                            setModalState(() {});
                          },
                          child: Container(
                            width: 78,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white12
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white30,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: clampedW,
                                  height: boxH,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white24
                                        : Colors.white12,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white38,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item['label'] as String,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                Text(
                                  item['social'] as String,
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 9),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Background Fill',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildFillOption(
                          'blur', 'Blur', Icons.blur_on, setModalState),
                      const SizedBox(width: 8),
                      _buildFillOption(
                          'black', 'Black', Icons.circle, setModalState),
                      const SizedBox(width: 8),
                      _buildFillOption('white', 'White',
                          Icons.circle_outlined, setModalState),
                      const SizedBox(width: 8),
                      _buildFillOption(
                          'crop', 'Crop', Icons.crop, setModalState),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Done',
                          style:
                          TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFillOption(String mode, String label, IconData icon,
      StateSetter setModalState) {
    final bool isSelected = _backgroundFillMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _backgroundFillMode = mode);
        setModalState(() {});
      },
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white12,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? Colors.white : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected ? Colors.black : Colors.white,
                size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontSize: 12,
                fontWeight: isSelected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sticker Picker ────────────────────────────────────────────────────────
  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            final stickers =
                _stickerCategories[_activeStickerCategory] ?? [];
            return Container(
              height: MediaQuery
                  .of(context)
                  .size
                  .height * 0.45,
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin:
                    const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: _stickerCategories.keys.map((cat) {
                        final bool selected =
                            cat == _activeStickerCategory;
                        return GestureDetector(
                          onTap: () {
                            setState(
                                    () => _activeStickerCategory = cat);
                            setModal(() {});
                          },
                          child: AnimatedContainer(
                            duration:
                            const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white
                                  : Colors.white12,
                              borderRadius:
                              BorderRadius.circular(20),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: selected
                                    ? Colors.black
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1,
                      ),
                      itemCount: stickers.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            _addSticker(stickers[index]);
                            Navigator.pop(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius:
                              BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                stickers[index],
                                style: const TextStyle(fontSize: 38),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _addSticker(String emoji) {
    setState(() {
      _placedStickers.add({
        'emoji': emoji,
        'x': 120.0,
        'y': 200.0,
        'scale': 1.0,
        'angle': 0.0,
      });
      _selectedStickerIndex = _placedStickers.length - 1;
    });
  }

  Widget _buildStickerLayer() {
    return Stack(
      children: _placedStickers
          .asMap()
          .entries
          .map((entry) {
        final i = entry.key;
        final s = entry.value;
        final bool isSelected = _selectedStickerIndex == i;
        return Positioned(
          left: (s['x'] as double) - 30,
          top: (s['y'] as double) - 30,
          child: GestureDetector(
            onTap: () =>
                setState(
                        () => _selectedStickerIndex = isSelected ? null : i),
            onScaleUpdate: (details) {
              setState(() {
                _placedStickers[i]['x'] =
                    (s['x'] as double) + details.focalPointDelta.dx;
                _placedStickers[i]['y'] =
                    (s['y'] as double) + details.focalPointDelta.dy;
                if (details.pointerCount >= 2) {
                  _placedStickers[i]['scale'] =
                      ((s['scale'] as double) * details.scale)
                          .clamp(0.3, 4.0);
                  _placedStickers[i]['angle'] =
                      (s['angle'] as double) + details.rotation;
                }
              });
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Transform.rotate(
                  angle: s['angle'] as double,
                  child: Transform.scale(
                    scale: s['scale'] as double,
                    child: Container(
                      decoration: isSelected
                          ? BoxDecoration(
                        border: Border.all(
                            color: Colors.white70, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      )
                          : null,
                      padding: const EdgeInsets.all(4),
                      child: Text(s['emoji'] as String,
                          style: const TextStyle(fontSize: 52)),
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: -10,
                    right: -10,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _placedStickers.removeAt(i);
                          _selectedStickerIndex = null;
                        });
                      },
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Aspect Ratio Canvas Preview ───────────────────────────────────────────
  Widget _buildAspectRatioCanvas() {
    final size = MediaQuery
        .of(context)
        .size;

    double targetAspectW = 9;
    double targetAspectH = 16;

    switch (_aspectRatio) {
      case '1:1':
        targetAspectW = 1;
        targetAspectH = 1;
        break;
      case '16:9':
        targetAspectW = 16;
        targetAspectH = 9;
        break;
      case '4:5':
        targetAspectW = 4;
        targetAspectH = 5;
        break;
      case '3:4':
        targetAspectW = 3;
        targetAspectH = 4;
        break;
      default:
        targetAspectW = 9;
        targetAspectH = 16;
    }

    final double targetRatio = targetAspectW / targetAspectH;
    final double screenRatio = size.width / size.height;

    double canvasW, canvasH;
    if (targetRatio < screenRatio) {
      canvasH = size.height;
      canvasW = canvasH * targetRatio;
    } else {
      canvasW = size.width;
      canvasH = canvasW / targetRatio;
    }

    return IgnorePointer(
      child: Stack(
        children: [
          Container(color: Colors.black),
          Center(
            child: SizedBox(
              width: canvasW,
              height: canvasH,
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(
                  _activeFilterMatrix ?? [
                    1, 0, 0, 0, 0,
                    0, 1, 0, 0, 0,
                    0, 0, 1, 0, 0,
                    0, 0, 0, 1, 0,
                  ],
                ),
                child: Image.file(
                  File(_editedMediaPath ?? widget.mediaPath),  // ← මෙකත්
                  fit: BoxFit.cover,
                  width: canvasW,
                  height: canvasH,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Enhance Sheet ─────────────────────────────────────────────────────────
  Widget _buildEnhanceSheet() {
    double brightness = 0.0;
    double contrast = 0.0;
    double saturation = 0.0;

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                      const Text(
                        'Enhance',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Enhancement applied!')),
                          );
                        },
                        icon: const Icon(Icons.check),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildEnhanceSlider(
                      'Brightness', brightness, Icons.brightness_6, (value) {
                    setModalState(() => brightness = value);
                  }),
                  const SizedBox(height: 20),
                  _buildEnhanceSlider(
                      'Contrast', contrast, Icons.contrast, (value) {
                    setModalState(() => contrast = value);
                  }),
                  const SizedBox(height: 20),
                  _buildEnhanceSlider(
                      'Saturation', saturation, Icons.color_lens, (value) {
                    setModalState(() => saturation = value);
                  }),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setModalState(() {
                        brightness = 0.0;
                        contrast = 0.0;
                        saturation = 0.0;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhanceSlider(String label,
      double value,
      IconData icon,
      ValueChanged<double> onChanged,) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(value.toStringAsFixed(1),
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: -100,
          max: 100,
          divisions: 200,
          activeColor: const Color(0xFF2196F3),
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ── Speed Control (Video Only) ────────────────────────────────────────────
  void _showSpeedControl() {
    final speeds = [
      {'label': '0.3x', 'value': 0.3},
      {'label': '0.5x', 'value': 0.5},
      {'label': '1x', 'value': 1.0},
      {'label': '1.5x', 'value': 1.5},
      {'label': '2x', 'value': 2.0},
      {'label': '3x', 'value': 3.0},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900]!.withOpacity(0.95),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose the speed now',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'For Slow-mo or Fast Motion',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: speeds.map((speed) {
                  final double speedValue = speed['value'] as double;
                  final String speedLabel = speed['label'] as String;
                  final bool isSelected =
                      _videoController?.value.playbackSpeed == speedValue;
                  return GestureDetector(
                    onTap: () {
                      _videoController?.setPlaybackSpeed(speedValue);
                      setState(() {});
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                          Text('Speed set to $speedLabel'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color:
                        isSelected ? Colors.blue : Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                            color: Colors.white, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          speedLabel,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // ── Helper: current video time ────────────────────────────────────────────
  double get _currentVideoTime =>
      _videoController?.value.position.inSeconds.toDouble() ?? 0.0;

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Popup open නම් close කරලා return
        if (_discardPopup != null) {
          _discardPopup!.remove();
          _discardPopup = null;
          return false;
        }
        _showDiscardOrSaveDraftSheet();
        return false;
      },
    child:  Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Main Media (Full Screen) ────────────────────────────────────
          Positioned.fill(
            child: widget.isVideo
                ? _videoController != null &&
                _videoController!.value.isInitialized
                ? GestureDetector(
              onTap: () {
                setState(() {
                  if (_videoController!.value.isPlaying) {
                    _videoController!.pause();
                    isPlaying = false;
                  } else {
                    _videoController!.play();
                    isPlaying = true;
                  }
                });
              },
              child: Stack(
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio:
                      _videoController!.value.aspectRatio,
                      child: ColorFiltered(
                        colorFilter: ColorFilter.matrix(
                          _activeFilterMatrix ?? [
                            1, 0, 0, 0, 0,
                            0, 1, 0, 0, 0,
                            0, 0, 1, 0, 0,
                            0, 0, 0, 1, 0,
                          ],
                        ),
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  ),
                  if (!isPlaying)
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                  ..._effectLayers.where((layer) {
                    final currentSec = _currentVideoTime;
                    return !widget.isVideo ||
                        (currentSec >= layer.startSec &&
                            currentSec <= layer.endSec);
                  }).map((layer) =>
                      Positioned.fill(
                        child: buildEffectOverlay(
                            layer.effectKey, layer.intensity),
                      )),
                  ..._textOverlays.map((overlay) =>
                      Positioned(
                        left: overlay.x,
                        top: overlay.y,
                        child: Draggable(
                          feedback: Material(
                            color: Colors.transparent,
                            child: AnimatedTextOverlayWidget(
                              overlay: overlay,
                              currentTime: _currentVideoTime,
                            ),
                          ),
                          childWhenDragging:
                          const SizedBox.shrink(),
                          onDragEnd: (details) {
                            setState(() {
                              overlay.x = details.offset.dx;
                              overlay.y = details.offset.dy;
                            });
                          },
                          child: AnimatedTextOverlayWidget(
                            overlay: overlay,
                            currentTime: _currentVideoTime,
                          ),
                        ),
                      )),
                ],
              ),
            )
                : const Center(
              child: CircularProgressIndicator(
                  color: Colors.white),
            )
                : Stack(
              fit: StackFit.expand,
              children: [
                ColorFiltered(
                  colorFilter: ColorFilter.matrix(
                    _activeFilterMatrix ?? [
                      1, 0, 0, 0, 0,
                      0, 1, 0, 0, 0,
                      0, 0, 1, 0, 0,
                      0, 0, 0, 1, 0,
                    ],
                  ),
                  child: Image.file(
                    File(_editedMediaPath ?? widget.mediaPath),  // ← මෙකත්
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                _buildAspectRatioCanvas(),
                ..._effectLayers.map((layer) =>
                    Positioned.fill(
                      child: buildEffectOverlay(
                          layer.effectKey, layer.intensity),
                    )),
                ..._imageStickers
                    .asMap()
                    .entries
                    .map(
                      (entry) =>
                      Positioned(
                        left: 50.0 * entry.key,
                        top: 50.0 * entry.key,
                        child: Draggable(
                          feedback: Text(entry.value,
                              style:
                              const TextStyle(fontSize: 40)),
                          childWhenDragging: Container(),
                          onDragEnd: (_) {},
                          child: Text(entry.value,
                              style:
                              const TextStyle(fontSize: 40)),
                        ),
                      ),
                ),
                // ← _buildStickerLayer() call තියෙනවා, ඊට පහළින් මෙක දෙන්න:
                if (_isBrushMode) _buildDrawingCanvas(),
                _buildStickerLayer(),
                // ← Bottom Toolbar Positioned block ඉහළින් brush bar දෙන්න:

                ..._textOverlays.map((overlay) =>
                    Positioned(
                      left: overlay.x,
                      top: overlay.y,
                      child: Draggable(
                        feedback: Material(
                          color: Colors.transparent,
                          child: AnimatedTextOverlayWidget(
                            overlay: overlay,
                            currentTime: 0,
                          ),
                        ),
                        childWhenDragging:
                        const SizedBox.shrink(),
                        onDragEnd: (details) {
                          setState(() {
                            overlay.x = details.offset.dx;
                            overlay.y = details.offset.dy;
                          });
                        },
                        child: AnimatedTextOverlayWidget(
                          overlay: overlay,
                          currentTime: 0,
                        ),
                      ),
                    )),
              ],
            ),
          ),

          // ── Top gradient ────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Top Bar ─────────────────────────────────────────────────────────────────
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _showDiscardOrSaveDraftSheet,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 24),
                  ),
                ),

                // ── Sound Bar (TikTok style) ──────────────────────────────
                if (showSongTitle)
                  GestureDetector(
                    // ✅ Replace කරන්න
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) =>
                            AudioPickerImproved(
                              onAudioSelected: (AudioTrackEnhanced? track) {
                                if (track != null) {
                                  setState(() {
                                    _selectedMusic    = track.title;
                                    _selectedMusicUrl = track.localPath ?? track.audioUrl;  // ✅ local first
                                    _selectedMusicId  = track.id;

                                    showSongTitle     = true;
                                  });
                                  if (!widget.isVideo) {
                                    _playImageAudioPreview(_selectedMusicUrl);
                                  }
                                }
                              },
                            ),
                      );
                    },
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 220),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Spinning disc icon
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF3B5C), Color(0xFF8B0000)],
                              ),
                            ),
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Scrolling song name
                          Flexible(
                            child: Text(
                              _selectedMusic ?? selectedSong,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Separator line
                          Container(
                            width: 1,
                            height: 14,
                            color: Colors.white.withOpacity(0.4),
                          ),
                          const SizedBox(width: 8),

                          // Change text
                          const Text(
                            'Change',
                            style: TextStyle(
                              color: Color(0xFFFF3B5C),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          const SizedBox(width: 6),

                          // Close button
                          GestureDetector(
                            onTap: () {
                              _stopImageAudioPreview(); // ✅ stop audio
                              setState(() => showSongTitle = false);
                            },
                            child: Icon(
                                Icons.close,
                                color: Colors.white.withOpacity(0.7),
                                size: 16
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(width: 44),
              ],
            ),
          ),
          // ── Multi-Media Thumbnail Strip ──────────────────────────────────
          // Shows when more than 1 media item exists, or when can add more
          if (_mediaPaths.length > 1 || _canAddMore())
            Positioned(
              top: 110,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 76,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _mediaPaths.length + (_canAddMore() ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Add more button
                    if (index == _mediaPaths.length) {
                      return GestureDetector(
                        onTap: _addMoreMedia,
                        child: Container(
                          width: 64,
                          height: 64,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white54,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add,
                                  color: Colors.white70, size: 22),
                              Text(
                                '${_mediaPaths.length}/${_getMaxLimit()}',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Thumbnail item
                    final path = _mediaPaths[index];
                    final isVid = _mediaIsVideo[index];
                    return Stack(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: index == 0
                                  ? const Color(0xFF58A6FF)
                                  : Colors.white38,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(
                              File(path),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Video indicator
                        if (isVid)
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.play_arrow,
                                  color: Colors.white, size: 12),
                            ),
                          ),
                        // Remove button (don't show for first/primary media)
                        if (index > 0)
                          Positioned(
                            top: -2,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeMedia(index),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 13),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
// ── Bottom gradient ──────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.95),
                  ],
                ),
              ),
            ),
          ),
          // ── Bottom Toolbar ───────────────────────────────────────────────
          // ඉදිරිපිට if add කරන්න:
          if (!_isBrushMode)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 100,
                padding: const EdgeInsets.only(bottom: 20, top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding:
                        const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            if (widget.isVideo) ...[
                              _buildToolbarButton(
                                icon: Icons.content_cut,
                                label: 'Trim',
                                onTap: _showTrimSlider,
                              ),
                              const SizedBox(width: 4),
                              _buildToolbarButton(
                                icon: Icons.volume_up,
                                label: 'Volume',
                                onTap: _showVolumeControls,
                              ),
                              const SizedBox(width: 4),
                              _buildToolbarButton(
                                icon: Icons.content_cut,
                                label: 'Clip',
                                onTap: _openEditBottomSheet,
                              ),
                              const SizedBox(width: 4),
                              _buildToolbarButton(
                                icon: Icons.music_note,
                                label: 'Music',
                                onTap: _showMusicLibrary,
                              ),
                              const SizedBox(width: 4),
                              _buildToolbarButton(
                                icon: Icons.filter_vintage,
                                label: 'Filter',
                                onTap: _openFilterBottomSheet,
                              ),
                              const SizedBox(width: 4),
                              _buildToolbarButton(
                                icon: Icons.auto_fix_high,
                                label: 'Effect',
                                onTap: _openEffectBottomSheet,
                              ),
                              const SizedBox(width: 4),
                              _buildToolbarButton(
                                icon: Icons.text_fields,
                                label: 'Text',
                                onTap: _showTextOverlay,
                              ),
                              const SizedBox(width: 4),
                              _buildToolbarButton(
                                icon: Icons.crop_square,
                                label: 'Canvas',
                                onTap: _openEnhanceBottomSheet,
                              ),
                              const SizedBox(width: 4),
                              _buildToolbarButton(
                                icon: Icons.subtitles,
                                label: 'Subtitle',
                                onTap: _openSubtitleBottomSheet,
                              ),
                              const SizedBox(width: 4),
                              _buildToolbarButton(
                                icon: Icons.list_alt,
                                label: 'Chapter',
                                onTap: () {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content: Text('Chapter feature'),
                                  ));
                                },
                              ),
                              const SizedBox(width: 4),
                              _buildToolbarButton(
                                icon: Icons.speed,
                                label: 'Speed',
                                onTap: _showSpeedControl,
                              ),
                            ],

                            if (!widget.isVideo) ...[
                              // ✅ NEW — මෙක දෙන්න මෙතන
                              _buildToolbarButton(
                                icon: Icons.brush,
                                label: 'Draw',
                                onTap: _openBrushTool,
                              ),
                              const SizedBox(width: 4),
                              _buildToolbarButton(
                                icon: Icons.crop,
                                label: 'Ratio',
                                onTap: _showAspectRatioOptions,
                              ),
                              const SizedBox(width: 4),
                              _buildToolbarButton(
                                icon: Icons.filter_vintage,
                                label: 'Filter',
                                onTap: _openFilterBottomSheet,
                              ),
                              const SizedBox(width: 4),
                              _buildToolbarButton(
                                icon: Icons.emoji_emotions,
                                label: 'Sticker',
                                onTap: _showStickerPicker,
                              ),
                              const SizedBox(width: 4),
                              _buildToolbarButton(
                                icon: Icons.text_fields,
                                label: 'Text',
                                onTap: _showTextOverlay,
                              ),
                              const SizedBox(width: 4),
                              _buildToolbarButton(
                                icon: Icons.auto_fix_high,
                                label: 'Effect',
                                onTap: _openEffectBottomSheet,
                              ),
                              const SizedBox(width: 4),
                              _buildToolbarButton(
                                icon: Icons.crop_square,
                                label: 'Canvas',
                                onTap: _openEnhanceBottomSheet,
                              ),
                              const SizedBox(width: 4),
                              _buildToolbarButton(
                                icon: Icons.music_note,
                                label: 'Music',
                                onTap: _showMusicLibrary,
                              ),

                            ],

                            const SizedBox(width: 8),


                          ],
                        ),
                      ),
                    ),
                    // ── Next Button ──────────────────────────────────────
                    Padding(
                      padding:
                      const EdgeInsets.only(right: 12, left: 4),
                      child: GestureDetector(
                        onTap: _navigateToPost,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF4458),
                                Color(0xFFE91E3A),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF4458)
                                    .withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_isBrushMode && !widget.isVideo) _buildBrushBottomBar(),
        ],
      ),
    ),
    );
  }


  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'Black & White':
        return Colors.grey.withOpacity(0.5);
      case 'Sepia':
        return Colors.brown.withOpacity(0.3);
      case 'Cool':
        return Colors.blue.withOpacity(0.2);
      case 'Warm':
        return Colors.orange.withOpacity(0.2);
      case 'Bright':
        return Colors.white.withOpacity(0.2);
      case 'Dark':
        return Colors.black.withOpacity(0.3);
      default:
        return Colors.transparent;
    }
  }

// ── Brush Tool ────────────────────────────────────────────────────────────
  void _openBrushTool() {
    setState(() {
      _isBrushMode = true;
      _redoPaths.clear();
    });
  }

  void _closeBrushTool({bool save = true}) async {
    if (save && _drawPaths.isNotEmpty) {
      await _applyBrushToImage();
    }
    setState(() {
      _isBrushMode = false;
      _drawPaths.clear();
      _redoPaths.clear();
    });
  }

  Widget _buildDrawingCanvas() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 280,
      // ← brush bottom bar height එක — bottom bar cover නොවෙන්න
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _currentPath = _DrawPath(
              points: [details.localPosition], // ← fix
              color: _brushColor,
              strokeWidth: _brushSize,
            );
            _drawPaths.add(_currentPath!);
            _redoPaths.clear();
          });
        },
        onPanUpdate: (details) {
          setState(() {
            if (_currentPath != null) {
              final updated = _currentPath!.copyWith(
                points: [
                  ..._currentPath!.points,
                  details.localPosition
                ], // ← fix
              );
              _drawPaths[_drawPaths.length - 1] = updated;
              _currentPath = updated;
            }
          });
        },
        onPanEnd: (_) {
          setState(() => _currentPath = null);
        },
        child: CustomPaint(
          painter: _BrushPainter(paths: _drawPaths),
          size: Size.infinite,
        ),
      ),
    );
  }

  Widget _buildBrushBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1117),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: Color(0xFF21262D), width: 1),
          ),
        ),
        height: 280,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Drag handle ───────────────────────────────────────────
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A5568),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Color circles ─────────────────────────────────────────
                SizedBox(
                  height: 64,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _brushColors.length,
                    itemBuilder: (context, index) {
                      final color = _brushColors[index];
                      final bool isSelected = _brushColor == color;
                      return GestureDetector(
                        onTap: () => setState(() => _brushColor = color),
                        child: Container(
                          width: 60,
                          height: 64,
                          alignment: Alignment.center,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: isSelected ? 50 : 40,
                            height: isSelected ? 50 : 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [BoxShadow(
                                color: color.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                              ]
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // ── X | undo redo | ✓ ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setState(() {
                              _drawPaths.clear();
                              _redoPaths.clear();
                              _isBrushMode = false;
                            }),
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.close, color: Colors.white70,
                              size: 32),
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (_drawPaths.isEmpty) return;
                              setState(() =>
                                  _redoPaths.add(_drawPaths.removeLast()));
                            },
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(Icons.undo_rounded,
                                color: _drawPaths.isEmpty
                                    ? Colors.white24
                                    : Colors.white60,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          GestureDetector(
                            onTap: () {
                              if (_redoPaths.isEmpty) return;
                              setState(() =>
                                  _drawPaths.add(_redoPaths.removeLast()));
                            },
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(Icons.redo_rounded,
                                color: _redoPaths.isEmpty
                                    ? Colors.white24
                                    : Colors.white60,
                                size: 30,
                              ),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _closeBrushTool(save: true),
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.check, color: Colors.white,
                              size: 32),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

// ── Change Sound Sheet (TikTok style) ───────────────────────────────────────
  void _showChangeSoundSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery
              .of(context)
              .size
              .height * 0.35,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              const Text(
                'Sound',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // Current song display
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF3B5C), Color(0xFF8B0000)],
                        ),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedMusic ?? selectedSong,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Original Sound',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Remove sound button
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            showSongTitle = false;
                            _selectedMusic = null;
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🔇 Sound removed'),
                              duration: Duration(seconds: 1),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.volume_off,
                                  color: Colors.white70, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Remove',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Change sound button
                    Expanded(
                      child: GestureDetector(
                        // ✅ Replace කරන්න
                        onTap: () {
                          Navigator.pop(context); // bottom sheet close
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) =>
                                AudioPickerImproved(
                                  onAudioSelected: (AudioTrackEnhanced? track) {
                                    if (track != null) {
                                      setState(() {
                                        _selectedMusic    = track.title;
                                        _selectedMusicUrl = track.localPath ?? track.audioUrl;
                                        _selectedMusicId  = track.id;
                                        _selectedMusicAlbumArt = null;
                                        showSongTitle     = true;
                                      });
                                      if (!widget.isVideo) {
                                        _playImageAudioPreview(_selectedMusicUrl);
                                      }
                                    }
                                  },
                                ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF3B5C), Color(0xFFE91E3A)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.swap_horiz,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Change',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _applyBrushToImage() async {
    final imageFile = File(_editedMediaPath ?? widget.mediaPath);
    final imageBytes = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final srcImage = frame.image;

    final imgW = srcImage.width.toDouble();
    final imgH = srcImage.height.toDouble();
    final screenSize = MediaQuery
        .of(context)
        .size;
    final scaleX = imgW / screenSize.width;
    final scaleY = imgH / screenSize.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, imgW, imgH));

    // ── Original image draw ──
    canvas.drawImage(srcImage, Offset.zero, Paint());

    // ── Brush paths draw (scaled) ──
    for (final path in _drawPaths) {
      if (path.points.length < 2) continue;
      final paint = Paint()
        ..color = path.color
        ..strokeWidth = path.strokeWidth * scaleX
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final drawPath = Path()
        ..moveTo(path.points.first.dx * scaleX, path.points.first.dy * scaleY);

      for (int i = 1; i < path.points.length - 1; i++) {
        final mid = Offset(
          (path.points[i].dx + path.points[i + 1].dx) / 2 * scaleX,
          (path.points[i].dy + path.points[i + 1].dy) / 2 * scaleY,
        );
        drawPath.quadraticBezierTo(
          path.points[i].dx * scaleX, path.points[i].dy * scaleY,
          mid.dx, mid.dy,
        );
      }
      drawPath.lineTo(
          path.points.last.dx * scaleX, path.points.last.dy * scaleY);
      canvas.drawPath(drawPath, paint);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(imgW.toInt(), imgH.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final tempDir = await getTemporaryDirectory();
    final newPath = '${tempDir.path}/brush_${DateTime
        .now()
        .millisecondsSinceEpoch}.png';
    await File(newPath).writeAsBytes(bytes);

    setState(() => _editedMediaPath = newPath);
  }
}
// ── Custom painter ────────────────────────────────────────────────────────
class _BrushPainter extends CustomPainter {
  final List<_DrawPath> paths;
  const _BrushPainter({required this.paths});

  @override
  void paint(Canvas canvas, Size size) {
    for (final path in paths) {
      if (path.points.length < 2) continue;
      final paint = Paint()
        ..color = path.color
        ..strokeWidth = path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final drawPath = Path()..moveTo(path.points.first.dx, path.points.first.dy);
      for (int i = 1; i < path.points.length - 1; i++) {
        final mid = Offset(
          (path.points[i].dx + path.points[i + 1].dx) / 2,
          (path.points[i].dy + path.points[i + 1].dy) / 2,
        );
        drawPath.quadraticBezierTo(
          path.points[i].dx, path.points[i].dy,
          mid.dx, mid.dy,
        );
      }
      drawPath.lineTo(path.points.last.dx, path.points.last.dy);
      canvas.drawPath(drawPath, paint);
    }
  }

  @override
  bool shouldRepaint(_BrushPainter old) => old.paths != paths;
}
// ── Drawing path model ────────────────────────────────────────────────────
class _DrawPath {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  const _DrawPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  _DrawPath copyWith({List<Offset>? points}) => _DrawPath(
    points: points ?? this.points,
    color: color,
    strokeWidth: strokeWidth,
  );
}
// ── Internal single-pick bottom sheet (wraps MeadiaFragment) ─────────────────
/// Returns the picked AssetEntity via Navigator.pop(context, asset)
class _MediaPickerSingleSheet extends StatefulWidget {
  const _MediaPickerSingleSheet();

  @override
  State<_MediaPickerSingleSheet> createState() =>
      _MediaPickerSingleSheetState();
}

class _MediaPickerSingleSheetState extends State<_MediaPickerSingleSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;

  List<AssetEntity> _mediaList = [];
  AssetEntity? _picked;
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  int _currentPage = 0;
  static const int pageSize = 50;
  bool permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _requestAndLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _stopImageAudioPreview(); // ✅ ADD
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        isLoading = true;
        _mediaList.clear();
        _currentPage = 0;
        hasMore = true;
        _picked = null;
      });
      _loadMedia();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!isLoadingMore && hasMore) _loadMoreMedia();
    }
  }

  Future<void> _requestAndLoad() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth || ps.hasAccess) {
      setState(() => permissionGranted = true);
      await _loadMedia();
    } else {
      setState(() { permissionGranted = false; isLoading = false; });
    }
  }

  RequestType get _reqType {
    switch (_tabController.index) {
      case 1: return RequestType.video;
      case 2: return RequestType.image;
      default: return RequestType.common;
    }
  }

  Future<List<AssetPathEntity>> _albums() => PhotoManager.getAssetPathList(
    type: _reqType,
    hasAll: true,
    filterOption: FilterOptionGroup(
      imageOption: const FilterOption(sizeConstraint: SizeConstraint(ignoreSize: true)),
      videoOption: const FilterOption(sizeConstraint: SizeConstraint(ignoreSize: true)),
      orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
    ),
  );

  Future<void> _loadMedia() async {
    if (!mounted) return;
    setState(() { isLoading = true; _currentPage = 0; hasMore = true; _mediaList.clear(); });
    try {
      final al = await _albums();
      if (al.isEmpty) { setState(() => isLoading = false); return; }
      final media = await al.first.getAssetListPaged(page: 0, size: pageSize);
      final total = await al.first.assetCountAsync;
      if (mounted) setState(() {
        _mediaList = media;
        _currentPage = 1;
        isLoading = false;
        hasMore = media.length >= pageSize && media.length < total;
      });
    } catch (_) { if (mounted) setState(() => isLoading = false); }
  }

  Future<void> _loadMoreMedia() async {
    if (isLoadingMore || !hasMore || !mounted) return;
    setState(() => isLoadingMore = true);
    try {
      final al = await _albums();
      if (al.isEmpty) { setState(() { hasMore = false; isLoadingMore = false; }); return; }
      final total = await al.first.assetCountAsync;
      final more = await al.first.getAssetListPaged(page: _currentPage, size: pageSize);
      if (mounted) setState(() {
        _mediaList.addAll(more);
        _currentPage++;
        hasMore = more.length >= pageSize && _mediaList.length < total;
        isLoadingMore = false;
      });
    } catch (_) { if (mounted) setState(() { isLoadingMore = false; hasMore = false; }); }
  }

  String _fmt(int seconds) {
    final d = Duration(seconds: seconds);
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: const Color(0xFF21262D), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle + title
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
            child: Column(children: [
              Container(
                width: 48, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A5568),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Add Media',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
            ]),
          ),

          // Tabs — same style as MeadiaFragment
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: Color(0xFF58A6FF), width: 3),
                insets: EdgeInsets.symmetric(horizontal: 40),
              ),
              labelColor: const Color(0xFF58A6FF),
              unselectedLabelColor: const Color(0xFF8B949E),
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              tabs: const [Tab(text: 'All'), Tab(text: 'Videos'), Tab(text: 'Photos')],
            ),
          ),
          const SizedBox(height: 12),

          // Grid
          SizedBox(
            height: 360,
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF58A6FF)))
                : !permissionGranted
                ? Center(child: ElevatedButton(
              onPressed: PhotoManager.openSetting,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF58A6FF)),
              child: const Text('Open Settings'),
            ))
                : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GridView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                cacheExtent: 1000,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4,
                ),
                itemCount: _mediaList.length + (isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _mediaList.length) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: Color(0xFF58A6FF), strokeWidth: 2),
                    ));
                  }
                  final asset = _mediaList[index];
                  final isSelected = _picked == asset;
                  return GestureDetector(
                    onTap: () => setState(() => _picked = isSelected ? null : asset),
                    child: Container(
                      decoration: BoxDecoration(
                        border: isSelected
                            ? Border.all(color: const Color(0xFF58A6FF), width: 3)
                            : null,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Stack(fit: StackFit.expand, children: [
                        FutureBuilder<Uint8List?>(
                          future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                          builder: (context, snap) {
                            if (snap.connectionState == ConnectionState.done && snap.hasData) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.memory(snap.data!, fit: BoxFit.cover,
                                    gaplessPlayback: true, cacheWidth: 200),
                              );
                            }
                            return Container(color: Colors.grey[800],
                              child: const Center(child: SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Color(0xFF58A6FF))),
                              )),
                            );
                          },
                        ),
                        if (asset.type == AssetType.video)
                          Positioned(bottom: 4, right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                                const SizedBox(width: 2),
                                Text(_fmt(asset.duration),
                                    style: const TextStyle(color: Colors.white,
                                        fontSize: 10, fontWeight: FontWeight.bold)),
                              ]),
                            ),
                          ),
                        if (isSelected)
                          Positioned(top: 4, right: 4,
                            child: Container(
                              width: 24, height: 24,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF58A6FF), shape: BoxShape.circle),
                              child: const Icon(Icons.check, color: Colors.white, size: 16),
                            ),
                          ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom bar — same style as MeadiaFragment
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Preview
                if (_picked != null)
                  Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8), color: Colors.grey[800]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FutureBuilder<Uint8List?>(
                          future: _picked!.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                          builder: (context, snap) {
                            if (snap.hasData && snap.data != null) {
                              return Image.memory(snap.data!, width: 64, height: 64, fit: BoxFit.cover);
                            }
                            return Container(color: Colors.grey[700],
                                child: const Icon(Icons.image, color: Colors.white54));
                          },
                        ),
                      ),
                    ),
                    Positioned(top: -8, right: -8,
                      child: GestureDetector(
                        onTap: () => setState(() => _picked = null),
                        child: Container(
                          width: 24, height: 24,
                          decoration: const BoxDecoration(
                              color: Color(0xFFFF3B5C), shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ])
                else
                  const SizedBox(width: 64),

                // Add button
                ElevatedButton(
                  onPressed: _picked != null
                      ? () => Navigator.pop(context, _picked)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B5C),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF21262D),
                    disabledForegroundColor: const Color(0xFF8B949E),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    minimumSize: const Size(140, 56),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Add', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Icon(Icons.add, size: 20),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _stopImageAudioPreview() {}
}