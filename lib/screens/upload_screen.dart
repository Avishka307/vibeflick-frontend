
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:my_vibe_flick/sample/text_create_screen.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:io';
import '../Effect/camera_face_effects_screen.dart';
import '../Live Streaming/live_stream_screen.dart';
import '../main.dart';
import '../sample/create_text_post_screen.dart';
import '../sample/nearby_post_card.dart';
import 'activity_selected_media.dart';
import 'text_post_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:photo_manager/photo_manager.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../Notification/audio_picker.dart';
import 'media_fragment.dart';
import 'stickers_screen.dart';
import 'package:permission_handler/permission_handler.dart';
// Filter Model
class CameraFilter {
  final String id;
  final String name;
  final ColorFilter? colorFilter;
  final Color thumbnailColor;
  final IconData icon;

  CameraFilter({
    required this.id,
    required this.name,
    required this.colorFilter,
    required this.thumbnailColor,
    required this.icon,
  });
}
class UploadScreen extends StatefulWidget {
  final String? preselectedSoundId;
  final String? preselectedSoundName;
  final String? preselectedSoundUrl;
  final String? preselectedSoundAlbumArt;

  const UploadScreen({
    super.key,
    this.preselectedSoundId,
    this.preselectedSoundName,
    this.preselectedSoundUrl,
    this.preselectedSoundAlbumArt,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> with TickerProviderStateMixin {
  String activeMode = 'video';
  bool isRecording = false;
  bool isPaused = false;
  String flashMode = 'off';
  int recordingTime = 0;
  String? currentEffect;

// Audio sync variables
  bool _isAudioBuffered = false;
  String? _bufferedAudioPath;
  DateTime? _recordStartTime;
  Duration _audioSyncOffset = Duration.zero;
  String? ghostFramePath;
  bool showGhostOverlay = false;
  double ghostOpacity = 0.3;

  List<VideoClip> recordedClips = [];
  List<int> clipDurations = [];
// Document 3 - Step 2: SIMULTANEOUS START

  final AudioPlayer _audioPlayer = AudioPlayer();
  AudioTrackEnhanced? selectedAudio;
  bool isAudioPlaying = false;
  late AnimationController _waveformController;
  Duration? audioPosition;
  Duration? audioDuration;

  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  Offset? _focusPoint;
  late AnimationController _focusAnimationController;

  double recordingSpeed = 1.0;
  bool showSpeedSelector = false;

  int timerSeconds = 0;
  bool isCountingDown = false;
  int countdown = 0;
  Timer? countdownTimer;
  bool showTimerSelector = false;

  double beautyLevel = 0.0;
  bool showBeautySlider = false;

  String selectedDuration = 'Video';
  final List<String> durations = ['Photo', 'Video', 'Nearby', 'Text', 'Live'];

  CameraController? _cameraController;
  List<CameraDescription>? cameras;
  bool isCameraInitialized = false;
  int selectedCameraIndex = 0;
  Timer? recordingTimer;

  late AnimationController _slideController;
  late AnimationController _recordScaleController;
  late Animation<double> _slideAnimation;
  late AnimationController _shimmerController;

  // Gallery preview variables
  Uint8List? latestImageThumbnail;
  Uint8List? latestStickerThumbnail;
  bool isLoadingGalleryPreview = true;

  // හදපු - Filter variables
  bool showFilterPanel = false;
  late AnimationController _filterPanelController;
  late Animation<Offset> _filterPanelAnimation;
  CameraFilter? selectedFilter;
  final ScrollController _filterScrollController = ScrollController();

  // Filters list
  late List<CameraFilter> filters;

  @override
  void initState() {
    super.initState();

    // හදපු - Initialize filters
    _initializeFilters();

    // Initialize animations first
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
    );

    _recordScaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )
      ..repeat(reverse: true);

    _focusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )
      ..repeat();

    // හදපු - Filter panel animation
    _filterPanelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _filterPanelAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _filterPanelController,
      curve: Curves.easeOut,
    ));

    _slideController.forward();

    // Initialize camera immediately (not waiting for anything)
    //_initializeCamera();
    _requestAllPermissionsAtOnce();
    // Load other data in background
    _loadDrafts();// ✅ Preselected sound from SoundDetailPage
    if (widget.preselectedSoundId != null) {
      selectedAudio = AudioTrackEnhanced(
        id: widget.preselectedSoundId!,
        title: widget.preselectedSoundName ?? 'Unknown Sound',
        artist: '',
        duration: 60,
        coverUrl: '',
        audioUrl: widget.preselectedSoundUrl ?? '',
        category: 'For You',
        localPath: null,
        trimStart: 0,
        trimEnd: 60,
      );
      debugPrint('🎵 Preselected sound loaded: ${selectedAudio?.title}');
    }
    _cleanupOldDrafts();
    _setupAudioListeners();
    _loadLatestGalleryImage();
    _loadLatestSticker();
  }

// හදපු - Initialize filters with color matrices
  void _initializeFilters() {
    filters = [
      CameraFilter(
        id: 'none',
        name: 'Original',
        colorFilter: null,
        thumbnailColor: Colors.grey,
        icon: Icons.block,
      ),
      CameraFilter(
        id: 'vintage',
        name: 'Vintage',
        colorFilter: ColorFilter.matrix([
          0.9, 0.5, 0.1, 0, 0,
          0.3, 0.8, 0.1, 0, 0,
          0.2, 0.3, 0.5, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: const Color(0xFFDEB887),
        icon: Icons.camera_roll,
      ),
      CameraFilter(
        id: 'cool',
        name: 'Cool',
        colorFilter: ColorFilter.matrix([
          0.8, 0, 0, 0, 0,
          0, 0.9, 0, 0, 0,
          0.2, 0.2, 1.2, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: const Color(0xFF4682B4),
        icon: Icons.ac_unit,
      ),
      CameraFilter(
        id: 'warm',
        name: 'Warm',
        colorFilter: ColorFilter.matrix([
          1.2, 0, 0, 0, 0,
          0, 1.0, 0, 0, 0,
          0, 0, 0.8, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: const Color(0xFFFF8C00),
        icon: Icons.wb_sunny,
      ),
      CameraFilter(
        id: 'bw',
        name: 'B&W',
        colorFilter: ColorFilter.matrix([
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: Colors.grey.shade700,
        icon: Icons.contrast,
      ),
      CameraFilter(
        id: 'sepia',
        name: 'Sepia',
        colorFilter: ColorFilter.matrix([
          0.393, 0.769, 0.189, 0, 0,
          0.349, 0.686, 0.168, 0, 0,
          0.272, 0.534, 0.131, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: const Color(0xFF704214),
        icon: Icons.photo_filter,
      ),
      CameraFilter(
        id: 'vibrant',
        name: 'Vibrant',
        colorFilter: ColorFilter.matrix([
          1.4, 0, 0, 0, 0,
          0, 1.4, 0, 0, 0,
          0, 0, 1.4, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: const Color(0xFFFF1493),
        icon: Icons.brightness_high,
      ),
      CameraFilter(
        id: 'dramatic',
        name: 'Dramatic',
        colorFilter: ColorFilter.matrix([
          1.5, 0, 0, 0, -20,
          0, 1.5, 0, 0, -20,
          0, 0, 1.5, 0, -20,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: Colors.black87,
        icon: Icons.wb_twilight,
      ),
      CameraFilter(
        id: 'pastel',
        name: 'Pastel',
        colorFilter: ColorFilter.matrix([
          0.9, 0.1, 0.1, 0, 20,
          0.1, 0.9, 0.1, 0, 20,
          0.1, 0.1, 0.9, 0, 20,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: const Color(0xFFFFB6C1),
        icon: Icons.palette,
      ),
      CameraFilter(
        id: 'sunset',
        name: 'Sunset',
        colorFilter: ColorFilter.matrix([
          1.3, 0, 0, 0, 0,
          0, 0.9, 0, 0, 0,
          0, 0, 0.6, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: const Color(0xFFFF6347),
        icon: Icons.wb_twilight,
      ),
      // නව filters
      CameraFilter(
        id: 'neon',
        name: 'Neon',
        colorFilter: ColorFilter.matrix([
          1.6, 0, 0, 0, 0,
          0, 1.3, 0.3, 0, 0,
          0.3, 0, 1.6, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: const Color(0xFFFF00FF),
        icon: Icons.electric_bolt,
      ),
      CameraFilter(
        id: 'arctic',
        name: 'Arctic',
        colorFilter: ColorFilter.matrix([
          0.7, 0.1, 0.2, 0, 10,
          0.1, 0.9, 0.1, 0, 15,
          0.2, 0.2, 1.3, 0, 20,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: const Color(0xFFB0E0E6),
        icon: Icons.ac_unit_outlined,
      ),
      CameraFilter(
        id: 'golden',
        name: 'Golden',
        colorFilter: ColorFilter.matrix([
          1.4, 0.2, 0, 0, 10,
          0.2, 1.2, 0, 0, 5,
          0, 0, 0.7, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: const Color(0xFFFFD700),
        icon: Icons.wb_incandescent,
      ),
      CameraFilter(
        id: 'moonlight',
        name: 'Moonlight',
        colorFilter: ColorFilter.matrix([
          0.6, 0.1, 0.2, 0, 5,
          0.1, 0.7, 0.2, 0, 10,
          0.2, 0.2, 0.9, 0, 15,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: const Color(0xFF4B0082),
        icon: Icons.nightlight_round,
      ),
      CameraFilter(
        id: 'cherry',
        name: 'Cherry',
        colorFilter: ColorFilter.matrix([
          1.2, 0.2, 0.2, 0, 10,
          0.1, 0.9, 0.2, 0, 5,
          0.2, 0.1, 0.8, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: const Color(0xFFFFB7C5),
        icon: Icons.local_florist,
      ),
      CameraFilter(
        id: 'ocean',
        name: 'Ocean',
        colorFilter: ColorFilter.matrix([
          0.6, 0.1, 0.1, 0, 0,
          0.1, 0.8, 0.2, 0, 5,
          0.2, 0.3, 1.1, 0, 10,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: const Color(0xFF006994),
        icon: Icons.waves,
      ),
      CameraFilter(
        id: 'autumn',
        name: 'Autumn',
        colorFilter: ColorFilter.matrix([
          1.3, 0.3, 0, 0, 0,
          0.2, 1.0, 0, 0, 0,
          0, 0, 0.6, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: const Color(0xFFD2691E),
        icon: Icons.park,
      ),
      CameraFilter(
        id: 'retro',
        name: 'Retro',
        colorFilter: ColorFilter.matrix([
          1.0, 0.3, 0.2, 0, 0,
          0.2, 0.9, 0.2, 0, 0,
          0.1, 0.1, 0.7, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: const Color(0xFFCD853F),
        icon: Icons.camera_enhance,
      ),
      CameraFilter(
        id: 'spring',
        name: 'Spring',
        colorFilter: ColorFilter.matrix([
          0.9, 0.2, 0, 0, 15,
          0.2, 1.1, 0.2, 0, 20,
          0, 0.2, 0.9, 0, 15,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: const Color(0xFF98FB98),
        icon: Icons.eco,
      ),
      CameraFilter(
        id: 'lavender',
        name: 'Lavender',
        colorFilter: ColorFilter.matrix([
          1.0, 0.2, 0.3, 0, 10,
          0.1, 0.8, 0.2, 0, 5,
          0.3, 0.2, 1.1, 0, 15,
          0, 0, 0, 1, 0,
        ]),
        thumbnailColor: const Color(0xFFE6E6FA),
        icon: Icons.spa,
      ),
    ];

    // Set default filter
    selectedFilter = filters[0];
  }

  Future<void> _loadLatestGalleryImage() async {
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();

      if (ps.isAuth || ps.hasAccess) {
        final List<AssetPathEntity> albums = await PhotoManager
            .getAssetPathList(
          type: RequestType.image,
          hasAll: true,
          onlyAll: true,
        );

        if (albums.isNotEmpty) {
          final recentAlbum = albums[0];
          final List<AssetEntity> recentAssets = await recentAlbum
              .getAssetListRange(
            start: 0,
            end: 1,
          );

          if (recentAssets.isNotEmpty) {
            final thumbnail = await recentAssets[0].thumbnailDataWithSize(
              const ThumbnailSize(200, 200),
            );

            if (mounted) {
              setState(() {
                latestImageThumbnail = thumbnail;
                isLoadingGalleryPreview = false;
              });
            }
          } else {
            if (mounted) {
              setState(() {
                isLoadingGalleryPreview = false;
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              isLoadingGalleryPreview = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            isLoadingGalleryPreview = false;
          });
        }
      }
    } catch (e) {
      print('Error loading gallery preview: $e');
      if (mounted) {
        setState(() {
          isLoadingGalleryPreview = false;
        });
      }
    }
  }

  Future<void> _loadLatestSticker() async {
    setState(() {
      latestStickerThumbnail = null;
    });
  }

  void _openGalleryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (
          context) => const MeadiaFragment(), // ← MeadiaFragment (typo එකම)
    );
  }

  void _openFaceEffects() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Camera not ready yet!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CameraFaceEffectsScreen(
              cameras: cameras!,
            ),
      ),
    );
  }

  // හදපු - Toggle filter panel
  void _toggleFilterPanel() {
    setState(() {
      showFilterPanel = !showFilterPanel;
    });

    if (showFilterPanel) {
      _filterPanelController.forward();
    } else {
      _filterPanelController.reverse();
    }
  }

  // හදපු - Select filter
  void _selectFilter(CameraFilter filter) {
    setState(() {
      selectedFilter = filter;
    });

    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎨 ${filter.name} filter applied'),
        duration: const Duration(milliseconds: 800),
        backgroundColor: filter.thumbnailColor,
      ),
    );
  }

// හදපු - Filter Panel Widget (build method එකෙන් පිටත දාන්න)
  Widget _buildFilterPanel() {
    return SlideTransition(
      position: _filterPanelAnimation,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.85),
              Colors.black.withOpacity(0.95),
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B5C),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Filters',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Selected filter name badge
                      if (selectedFilter != null && selectedFilter!.id != 'none')
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B5C).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFFF3B5C).withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            selectedFilter!.name,
                            style: const TextStyle(
                              color: Color(0xFFFF3B5C),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _toggleFilterPanel,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Filter List ──
            Expanded(
              child: ListView.builder(
                controller: _filterScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                itemCount: filters.length,
                itemBuilder: (context, index) {
                  final filter = filters[index];
                  return _buildFilterItem(filter);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

// හදපු - Filter Item Widget
  Widget _buildFilterItem(CameraFilter filter) {
    final isSelected = selectedFilter?.id == filter.id;

    return GestureDetector(
      onTap: () => _selectFilter(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: isSelected ? 72 : 64,
        margin: EdgeInsets.only(
          right: 10,
          top: isSelected ? 0 : 6,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Thumbnail Circle ──
            Stack(
              alignment: Alignment.center,
              children: [
                // Glow effect when selected
                if (isSelected)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: filter.thumbnailColor.withOpacity(0.6),
                          blurRadius: 18,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),

                // Outer ring (selected = colored, unselected = white faint)
                Container(
                  width: isSelected ? 64 : 56,
                  height: isSelected ? 64 : 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? filter.thumbnailColor
                          : Colors.white.withOpacity(0.25),
                      width: isSelected ? 2.5 : 1.5,
                    ),
                  ),
                ),

                // Inner colored circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 56 : 50,
                  height: isSelected ? 56 : 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? LinearGradient(
                      colors: [
                        filter.thumbnailColor,
                        filter.thumbnailColor.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : LinearGradient(
                      colors: [
                        filter.thumbnailColor.withOpacity(0.75),
                        filter.thumbnailColor.withOpacity(0.45),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(
                    filter.icon,
                    color: Colors.white,
                    size: isSelected ? 26 : 22,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 7),

            // ── Label ──
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.55),
                fontSize: isSelected ? 11 : 10,
                fontWeight:
                isSelected ? FontWeight.w700 : FontWeight.w400,
                letterSpacing: 0.2,
              ),
              child: Text(
                filter.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ── Selected dot indicator ──
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 16 : 0,
              height: isSelected ? 3 : 0,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B5C),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // හදපු - Swipe to change filter
  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (details.primaryVelocity == null) return;

    final currentIndex = filters.indexOf(selectedFilter!);

    if (details.primaryVelocity! < 0) {
      // Swipe left - next filter
      if (currentIndex < filters.length - 1) {
        _selectFilter(filters[currentIndex + 1]);
      }
    } else if (details.primaryVelocity! > 0) {
      // Swipe right - previous filter
      if (currentIndex > 0) {
        _selectFilter(filters[currentIndex - 1]);
      }
    }
  }

  void _setupAudioListeners() {
    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        audioPosition = position;
      });
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        audioDuration = duration;
      });
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        isAudioPlaying = false;
        audioPosition = Duration.zero;
      });
    });
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        _cameraController = CameraController(
          cameras![selectedCameraIndex],
          ResolutionPreset.high,
          enableAudio: true,
          // imageFormatGroup.jpeg ඉවත් කළා - video recording block කරනවා
        );

        await _cameraController!.initialize();

        _maxZoomLevel = await _cameraController!.getMaxZoomLevel();
        _minZoomLevel = await _cameraController!.getMinZoomLevel();

        if (mounted) {
          setState(() {
            isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        setState(() {
          isCameraInitialized = false;
        });
      }
    }
  }

  Future<void> _loadDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final draftsJson = prefs.getString('video_drafts');
    if (draftsJson != null) {
      final List<dynamic> draftsList = json.decode(draftsJson);
      setState(() {
        recordedClips =
            draftsList.map((item) => VideoClip.fromJson(item)).toList();
      });
    }
  }

  Future<void> _saveDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final draftsJson = json.encode(
        recordedClips.map((clip) => clip.toJson()).toList());
    await prefs.setString('video_drafts', draftsJson);
  }

  Future<void> _cleanupOldDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final draftsJson = prefs.getString('video_drafts');

    if (draftsJson != null) {
      final List<dynamic> draftsList = json.decode(draftsJson);
      final now = DateTime.now();
      final cutoffDate = now.subtract(const Duration(days: 2));

      List<VideoClip> validClips = [];
      int deletedCount = 0;

      for (var item in draftsList) {
        final clip = VideoClip.fromJson(item);
        final clipDate = DateTime.parse(clip.timestamp);

        if (clipDate.isAfter(cutoffDate)) {
          validClips.add(clip);
        } else {
          try {
            final file = File(clip.path);
            if (await file.exists()) {
              await file.delete();
              deletedCount++;
            }
          } catch (e) {
            print('Error deleting old draft: $e');
          }
        }
      }

      await prefs.setString(
        'video_drafts',
        json.encode(validClips.map((clip) => clip.toJson()).toList()),
      );

      if (deletedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '🧹 Cleaned up $deletedCount old draft${deletedCount > 1
                    ? 's'
                    : ''}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    debugPrint('🛑 Disposing UploadScreen...');

    // Cancel timers first
    recordingTimer?.cancel();
    countdownTimer?.cancel();

    // Stop & dispose audio
    _audioPlayer.stop();
    _audioPlayer.dispose();

    // Dispose camera safely (ONLY ONCE!)
    if (_cameraController != null) {
      try {
        _cameraController!.dispose();
        debugPrint('✅ Camera disposed');
      } catch (e) {
        debugPrint('⚠️ Camera disposal error (ignored): $e');
      }
    }

    // Dispose animations
    _slideController.dispose();
    _recordScaleController.dispose();
    _waveformController.dispose();
    _focusAnimationController.dispose();
    _shimmerController.dispose();
    _filterPanelController.dispose();
    _filterScrollController.dispose();

    super.dispose();
  }

// ✅ මේ method එක _UploadScreenState class එක ඇතුලේ දාන්න (dispose method එකට උඩින් හෝ යටින්)
  void _handleCloseButton() {
    debugPrint('🚪 Close button pressed');

    // 🛑 STEP 1: Stop recording if active
    if (isRecording) {
      debugPrint('⏹️ Stopping active recording...');
      handleStopRecording();
    }

    // 🛑 STEP 2: Stop audio if playing
    if (isAudioPlaying) {
      debugPrint('🔇 Stopping audio...');
      _audioPlayer.stop();
    }

    // 🛑 STEP 3: Dispose camera safely
    if (_cameraController != null) {
      try {
        debugPrint('📷 Disposing camera...');
        _cameraController!.dispose();
        debugPrint('✅ Camera disposed');
      } catch (e) {
        debugPrint('⚠️ Camera disposal error (ignored): $e');
      }
    }

    // ✅ STEP 4: Navigate back to MainScreen (Home tab)
    if (mounted) {
      debugPrint('🏠 Navigating to MainScreen...');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
      );
    }
  }

  int getMaxDuration() {
    if (selectedDuration == 'Photo') return 0;
    if (selectedDuration == 'Video') return 60;
    return 60;
  }

  void handleDurationSelection(String duration) {
    // ✅ Nearby button - Navigate to NearbyFeedScreen
    if (duration == 'Nearby') {
      HapticFeedback.lightImpact();

      debugPrint('📍 Navigating to Nearby Feed...');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CreateTextPostScreen(),
        ),
      );
      return;
    }


    if (duration == 'Live') { ScaffoldMessenger.of(context).showSnackBar( const SnackBar( content: Text('📺 Live streaming coming soon!'), duration: Duration(seconds: 2), ), ); return; }

    // ✅ Text button - Navigate to TextPostScreen
    if (duration == 'Text') {
      HapticFeedback.lightImpact();

      debugPrint('📝 Navigating to Text Post Creator...');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const TextPostScreen(),
        ),
      );
      return;
    }

    if (isRecording) {
      handleStopRecording();
    }

    setState(() {
      selectedDuration = duration;
      if (duration == 'Photo') {
        activeMode = 'photo';
        _slideController.forward();
      } else {
        activeMode = 'video';
        _slideController.reverse();
      }
    });
  }
  void handleFlipCamera() async {
    if (cameras == null || cameras!.isEmpty) return;

    setState(() {
      selectedCameraIndex = selectedCameraIndex == 0 ? 1 : 0;
      isCameraInitialized = false;
    });

    await _cameraController?.dispose();

    _cameraController = CameraController(
      cameras![selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: true,
      // imageFormatGroup.jpeg ඉවත් කළා
    );

    await _cameraController!.initialize();
    _maxZoomLevel = await _cameraController!.getMaxZoomLevel();
    _minZoomLevel = await _cameraController!.getMinZoomLevel();

    if (mounted) {
      setState(() {
        isCameraInitialized = true;
        _currentZoomLevel = 1.0;
      });
    }
  }

  void handleFlashToggle() {
    final modes = ['off', 'auto', 'always'];
    final currentIndex = modes.indexOf(flashMode);
    final nextIndex = (currentIndex + 1) % modes.length;
    setState(() {
      flashMode = modes[nextIndex];
    });

    if (_cameraController != null) {
      FlashMode mode = FlashMode.off;
      if (flashMode == 'auto') mode = FlashMode.auto;
      if (flashMode == 'always') mode = FlashMode.always;
      _cameraController!.setFlashMode(mode);
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _currentZoomLevel = (_currentZoomLevel * details.scale)
        .clamp(_minZoomLevel, _maxZoomLevel);

    _cameraController!.setZoomLevel(_currentZoomLevel);
  }

  void _handleTapToFocus(TapUpDetails details) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset localPosition = renderBox.globalToLocal(
        details.globalPosition);
    final Size size = renderBox.size;

    final double x = localPosition.dx / size.width;
    final double y = localPosition.dy / size.height;

    setState(() {
      _focusPoint = Offset(localPosition.dx, localPosition.dy);
    });

    _focusAnimationController.forward().then((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _focusPoint = null;
          });
        }
      });
    });

    try {
      await _cameraController!.setFocusPoint(Offset(x, y));
      await _cameraController!.setExposurePoint(Offset(x, y));
    } catch (e) {
      print('Error setting focus: $e');
    }
  }

  Future<void> _selectAudio() async {
    if (isAudioPlaying) {
      await _audioPlayer.stop();
      setState(() {
        isAudioPlaying = false;
      });
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AudioPickerImproved(
        onAudioSelected: (AudioTrackEnhanced? track) {
          setState(() {
            if (track != null) {
              selectedAudio = track;
            } else {
              selectedAudio = null;
            }
          });

          // Document 3 - Step 1: Pre-buffer as soon as audio selected
          if (track != null) {
            debugPrint('🎵 Audio selected - starting pre-buffer...');
            _isAudioBuffered = false;
            _preBufferAudio();
          }

          if (track != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.music_note, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '🎵 ${track.title} - ${track.artist}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (track.trimStart > 0 ||
                              track.trimEnd < track.duration)
                            Text(
                              'Trimmed: ${_formatDuration(track.trimStart.toInt())} - ${_formatDuration(track.trimEnd.toInt())}',
                              style: const TextStyle(fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 3),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🔇 Recording without sound'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(
        2, '0')}';
  }

  void _toggleSpeedSelector() {
    setState(() {
      showSpeedSelector = !showSpeedSelector;
    });
  }

  void _setRecordingSpeed(double speed) {
    setState(() {
      recordingSpeed = speed;
      showSpeedSelector = false;
    });

    String speedLabel = '';
    if (speed == 0.3)
      speedLabel = 'Ultra Slow (0.3x)';
    else if (speed == 0.5)
      speedLabel = 'Slow (0.5x)';
    else if (speed == 1.0)
      speedLabel = 'Normal (1x)';
    else if (speed == 2.0)
      speedLabel = 'Fast (2x)';
    else if (speed == 3.0) speedLabel = 'Ultra Fast (3x)';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚡ Speed: $speedLabel'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFFFF3B5C),
      ),
    );
  }

  void _toggleTimer() {
    setState(() {
      showTimerSelector = !showTimerSelector;
    });
  }

  void _setTimerDuration(int seconds) {
    setState(() {
      timerSeconds = seconds;
      showTimerSelector = false;
    });

    if (seconds == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏰ Timer OFF'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.grey,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏰ Timer set to ${seconds}s'),
          duration: const Duration(seconds: 1),
          backgroundColor: const Color(0xFFFF3B5C),
        ),
      );
    }
  }

  void _startCountdown() {
    if (timerSeconds == 0) {
      handleRecordPress();
      return;
    }

    setState(() {
      isCountingDown = true;
      countdown = timerSeconds;
    });

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _playBeepAndVibrate();

      setState(() {
        countdown--;
      });

      if (countdown <= 0) {
        timer.cancel();
        setState(() {
          isCountingDown = false;
        });

        // Show "Action!" message briefly then start recording
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            handleRecordPress();
          }
        });
      }
    });
  }

  void _playBeepAndVibrate() {
    HapticFeedback.mediumImpact();
  }

  void _cancelCountdown() {
    countdownTimer?.cancel();
    setState(() {
      isCountingDown = false;
      countdown = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⏰ Timer cancelled'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _toggleBeautySlider() {
    setState(() {
      showBeautySlider = !showBeautySlider;
    });
  }

// Document 3 - Step 2: Trigger Logic
// Record button + Audio දෙකම EXACTLY එකවර start කරනවා
  Future<void> handleRecordPress() async {
    if (selectedDuration == 'Photo') {
      // Photo mode
      _recordScaleController.forward().then((_) {
        _recordScaleController.reverse();
      });

      if (_cameraController != null &&
          _cameraController!.value.isInitialized) {
        try {
          final XFile imageFile = await _cameraController!.takePicture();
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SelectedMediaScreen(
                  mediaPath: imageFile.path,
                  isVideo: false,
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('Error taking photo: $e');
        }
      }
      return;
    }

    // Video mode - recording start
    if (!isRecording) {
      _recordScaleController.forward().then((_) {
        _recordScaleController.reverse();
      });

      if (_cameraController != null &&
          _cameraController!.value.isInitialized) {
        try {
          // Document 3 - Step 1: Pre-buffer check
          // Buffer කරලා නැත්නම් දැන් buffer කරන්න
          if (selectedAudio != null && !_isAudioBuffered) {
            debugPrint('🎵 Pre-buffering audio before record...');
            await _preBufferAudio();
          }

          // Document 3 - Step 2: SIMULTANEOUS START
// Camera සහ Audio දෙකම EXACTLY SAME MOMENT එකේ start කරනවා
          _recordStartTime = DateTime.now();

// Camera recording start
          // ── OLD (ලැග් කරනවා) ──
          final cameraFuture = _cameraController!.startVideoRecording();

          if (selectedAudio != null) {
            Future.microtask(() async {
              try {
                final playPath = _bufferedAudioPath ?? selectedAudio!.localPath;
                final startPosition = Duration(seconds: selectedAudio!.trimStart.toInt());

                // Audio play - non-blocking (lag නෑ)
                final playFuture = (playPath != null && playPath != selectedAudio!.audioUrl)
                    ? _audioPlayer.play(DeviceFileSource(playPath), position: startPosition)
                    : _audioPlayer.play(UrlSource(selectedAudio!.audioUrl), position: startPosition);

                // Camera ready වෙනකල් wait - audio parallel load වෙනවා
                await playFuture;
                debugPrint('▶️ Audio playing');

                final audioRate = _getInverseAudioRate();
                _setAudioSpeedWithPitchCorrection(audioRate); // await නෑ - non-blocking

                if (mounted) {
                  setState(() {
                    isAudioPlaying = true;
                  });
                }

                final trimDuration = selectedAudio!.trimEnd - selectedAudio!.trimStart;
                final maxAllowed = getMaxDuration();
                final stopAfter = trimDuration < maxAllowed
                    ? trimDuration
                    : maxAllowed.toDouble();

                Future.delayed(Duration(seconds: stopAfter.toInt()), () {
                  if (mounted && isAudioPlaying && isRecording) {
                    _audioPlayer.pause();
                    if (mounted) setState(() => isAudioPlaying = false);
                    debugPrint('⏹️ Audio auto-stopped after ${stopAfter}s');
                  }
                });
              } catch (e) {
                debugPrint('⚠️ Audio play error: $e');
              }
            });
          }
          // Camera start complete වෙනකල් wait
          await cameraFuture;
          setState(() {
            isRecording = true;
            isPaused = false;
            recordingTime = 0;
            _isAudioBuffered = false; // Reset for next use
          });

          recordingTimer?.cancel();

          // Document 3 - Step 4: 60s limit timer
          final int timerInterval = (1000 / recordingSpeed).round();

          recordingTimer = Timer.periodic(
            Duration(milliseconds: timerInterval),
                (timer) {
              if (!mounted || !isRecording || isPaused) return;

              recordingTime++; // setState නෑ - direct increment

              // UI update: 5 seconds කට වරක් විතරයි
              if (recordingTime % 5 == 0 && mounted) {
                setState(() {});
              }

              if (recordingTime >= getMaxDuration()) {
                debugPrint('⏰ Max duration reached - auto stop');
                timer.cancel();
                handleStopRecording();
              }
            },
          );

          debugPrint('🎬 Recording + Audio started SIMULTANEOUSLY');
        } catch (e) {
          debugPrint('Error starting recording: $e');
          if (mounted) {
            setState(() {
              isRecording = false;
              recordingTime = 0;
              isAudioPlaying = false;
            });
            // Audio stop කරන්න error නම්
            await _audioPlayer.stop();
          }
        }
      }
    }
  }
  Future<void> _testAudioPlayback() async {
    debugPrint('🔊 Testing audio...');
    debugPrint('selectedAudio: ${selectedAudio?.title}');
    debugPrint('localPath: ${selectedAudio?.localPath}');
    debugPrint('audioUrl: ${selectedAudio?.audioUrl}');

    try {
      if (selectedAudio?.localPath != null) {
        final file = File(selectedAudio!.localPath!);
        final exists = await file.exists();
        debugPrint('File exists: $exists');
        debugPrint('File size: ${await file.length()} bytes');
      }

      await _audioPlayer.play(
        selectedAudio?.localPath != null
            ? DeviceFileSource(selectedAudio!.localPath!)
            : UrlSource(selectedAudio!.audioUrl),
      );
      debugPrint('✅ Play called successfully');
    } catch (e) {
      debugPrint('❌ Audio error: $e');
    }
  }
  void handlePauseResumeRecording() async {
    if (!isRecording) return;

    if (_cameraController != null &&
        _cameraController!.value.isRecordingVideo) {
      if (!isPaused) {
        try {
          final video = await _cameraController!.stopVideoRecording();

          final clip = VideoClip(
            path: video.path,
            duration: recordingTime,
            timestamp: DateTime.now().toIso8601String(),
            speed: recordingSpeed,
          );

          recordedClips.add(clip);
          clipDurations.add(recordingTime);

          setState(() {
            isPaused = true;
          });

          if (isAudioPlaying) {
            _audioPlayer.pause();
          }

          _saveDrafts();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⏸️ Paused - Clip ${recordedClips.length} saved'),
              duration: const Duration(seconds: 1),
              backgroundColor: Colors.orange,
            ),
          );
        } catch (e) {
          print('Error pausing recording: $e');
        }
      } else {
        try {
          await _cameraController!.startVideoRecording();

          setState(() {
            isPaused = false;
            recordingTime =
                clipDurations.fold(0, (sum, duration) => sum + duration);
          });

          if (isAudioPlaying && selectedAudio != null) {
            _audioPlayer.resume();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('▶️ Resumed recording'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          print('Error resuming recording: $e');
        }
      }
    }
  }

  void _deleteLastClip() {
    if (recordedClips.isEmpty) return;

    setState(() {
      final lastClip = recordedClips.removeLast();
      final lastDuration = clipDurations.removeLast();
      recordingTime -= lastDuration;

      try {
        File(lastClip.path).deleteSync();
      } catch (e) {
        print('Error deleting clip: $e');
      }
    });

    _saveDrafts();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗑️ Last clip deleted'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void handleStopRecording() async {
    if (!isRecording) return;
    // ✅ Stop කරන්න කලින් duration save කරන්නSelectedMediaScreen
    final int savedDuration = recordingTime;
    debugPrint('💾 Saving duration: ${savedDuration}s before clear');
    setState(() {
      isRecording = false;
      isPaused = false;
      _isAudioBuffered = false;
    });

    recordingTimer?.cancel();
    recordingTimer = null;


    if (isAudioPlaying) {
      _audioPlayer.stop();
      setState(() {
        isAudioPlaying = false;
        audioPosition = Duration.zero;
      });
    }

    if (_cameraController != null &&
        _cameraController!.value.isRecordingVideo) {
      try {
        final video = await _cameraController!.stopVideoRecording();

        final clip = VideoClip(
          path: video.path,
          duration: recordingTime,
          timestamp: DateTime.now().toIso8601String(),
          speed: recordingSpeed,
        );

        recordedClips.add(clip);

        if (mounted) {
          // Loading indicator පෙන්වන්න
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF3B5C)),
            ),
          );

          // ── Merge or single clip ──────────────────────────────────
          String finalPath;

          if (recordedClips.length == 1) {
            finalPath = recordedClips.first.path;
            debugPrint('📹 Single clip: $finalPath');
          } else {
            finalPath = recordedClips.first.path;
            debugPrint('📹 Multi-clip (${recordedClips.length} clips) → using first: $finalPath');
          }

          // Temp clips cleanup (first clip හැර)
          for (int i = 1; i < recordedClips.length; i++) {
            try {
              final f = File(recordedClips[i].path);
              if (await f.exists()) await f.delete();
            } catch (_) {}
          }

          // ↓ මෙහෙම කරන්න - duration save කරලා clear කරන්න

          setState(() {
            recordedClips.clear();
            clipDurations.clear();
            recordingTime = 0;
          });
          _saveDrafts();

          // ↓↓↓ NEW: Speed + Audio Post-Processing ↓↓↓
          final speedProcessed = await _processVideoSpeedWithFFmpeg(finalPath);
          final mergedFinal = await _mergeOriginalAudioToVideo(
            speedProcessed ?? finalPath,
            savedDuration, // ← pass කරන්න
          );
          finalPath = mergedFinal ?? finalPath;
          // ↑↑↑ NEW: ඉවරයි ↑↑↑

          // Loading dismiss
          if (mounted) Navigator.of(context, rootNavigator: true).pop();

          // ── Navigate to SelectedMediaScreen ──────────────────────
          // ── Navigate to SelectedMediaScreen ──────────────────────
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SelectedMediaScreen(
                  mediaPath: finalPath,
                  isVideo: true,
                  initialFilterMatrix: selectedFilter?.colorFilter != null
                      ? _getColorFilterMatrix(selectedFilter!)
                      : null,
                ),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error stopping recording: $e');
        if (mounted) {
          setState(() {
            recordingTime = 0;
          });
        }
      }
    }
  }
  IconData getFlashIcon() {
    switch (flashMode) {
      case 'always':
        return Icons.flash_on;
      case 'auto':
        return Icons.flash_auto;
      default:
        return Icons.flash_off;
    }
  }

  String formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(
        2, '0')}';
  }

  Widget _buildBeautyOverlay() {
    if (beautyLevel == 0) return Container();

    return BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: beautyLevel * 2,
        sigmaY: beautyLevel * 2,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Colors.white.withOpacity(0.1 * beautyLevel),
              Colors.pink.withOpacity(0.05 * beautyLevel),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey[900]!,
                Colors.grey[800]!,
                Colors.grey[900]!,
              ],
              stops: [
                _shimmerController.value - 0.3,
                _shimmerController.value,
                _shimmerController.value + 0.3,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white54,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Initializing camera...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF3B5C)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  // ─── Method 3: FFmpeg Video Speed Processor ────────────────────────────────
// Video file එකේ actual speed change කරනවා
// 0.5x recording → 2x speedup | 2x recording → 0.5x slowdown
  Future<String?> _processVideoSpeedWithFFmpeg(String inputPath) async {
    if (recordingSpeed == 1.0) {
      debugPrint('⚡ Speed 1x — no processing needed');
      return inputPath; // Process කරන්නෙ නෑ
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/speed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // FFmpeg PTS formula:
      // setpts=0.5*PTS  → 2x fast  (recording 0.5x slow → output 2x fast)
      // setpts=2.0*PTS  → 0.5x slow (recording 2x fast → output 0.5x slow)
      final ptsValue = 1.0 / recordingSpeed;

      // Audio tempo filter (pitch correct):
      // atempo range: 0.5 - 2.0 only!
      // Speed 4x නම් chain කරන්න: atempo=2.0,atempo=2.0
      String audioFilter = _buildAudioTempoFilter(recordingSpeed);

      final command =
          '-i "$inputPath" '
          '-vf "setpts=${ptsValue.toStringAsFixed(4)}*PTS" '
          '-af "$audioFilter" '
          '-c:v mpeg4 ' // Hardware encode
          '-preset fast '
          '-y "$outputPath"';

      debugPrint('🎬 FFmpeg processing: ${recordingSpeed}x → $command');

      // FFmpeg execute
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (returnCode?.isValueSuccess() == true) {
        debugPrint('✅ Video speed processed: $outputPath');
        return outputPath;
      } else {
        final logs = await session.getOutput();
        debugPrint('❌ FFmpeg failed: $logs');
        return inputPath; // Fallback: original
      }
    } catch (e) {
      debugPrint('⚠️ Video processing error: $e');
      return inputPath;
    }
  }

// atempo 0.5-2.0 limit handle කරන helper
  String _buildAudioTempoFilter(double speed) {
    // Video fast → audio slow | Video slow → audio fast
    double tempo = 1.0 / speed; // Inverse

    if (tempo >= 0.5 && tempo <= 2.0) {
      return 'atempo=${tempo.toStringAsFixed(4)}'; // Direct
    } else if (tempo > 2.0) {
      // 2.0 chain: atempo=2.0,atempo=...
      double remaining = tempo;
      List<String> filters = [];
      while (remaining > 2.0) {
        filters.add('atempo=2.0');
        remaining /= 2.0;
      }
      filters.add('atempo=${remaining.toStringAsFixed(4)}');
      return filters.join(',');
    } else {
      // 0.5 chain
      double remaining = tempo;
      List<String> filters = [];
      while (remaining < 0.5) {
        filters.add('atempo=0.5');
        remaining /= 0.5;
      }
      filters.add('atempo=${remaining.toStringAsFixed(4)}');
      return filters.join(',');
    }
  }
  // ─── Method 4: Original Audio Merger ───────────────────────────────────────
// Speed-changed video + Original 1x audio = Final output
  Future<String?> _mergeOriginalAudioToVideo(
      String processedVideoPath, int durationSeconds) async {
    if (selectedAudio == null) {
      debugPrint('🔇 No audio selected — skip merge');
      return processedVideoPath;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/final_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final audioSource = _bufferedAudioPath ??
          selectedAudio!.localPath ??
          selectedAudio!.audioUrl;

      final trimStart = selectedAudio!.trimStart.toStringAsFixed(2);

      // Duration 0 නම් fallback
      final videoDuration =
      durationSeconds > 0 ? durationSeconds : 30;

      debugPrint('🎵 Merging: duration=${videoDuration}s, '
          'trimStart=${trimStart}s, audio=$audioSource');

      final command = '-i "$processedVideoPath" '
          '-ss $trimStart '
          '-i "$audioSource" '
          '-c:v copy '
          '-c:a aac '
          '-map 0:v:0 '
          '-map 1:a:0 '
          '-t $videoDuration '
          '-shortest '
          '-y "$outputPath"';

      debugPrint('🎬 FFmpeg merge command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (returnCode?.isValueSuccess() == true) {
        debugPrint('✅ Audio merged: $outputPath');
        return outputPath;
      } else {
        final logs = await session.getOutput();
        debugPrint('❌ Merge failed: $logs');
        return processedVideoPath;
      }
    } catch (e) {
      debugPrint('⚠️ Merge error: $e');
      return processedVideoPath;
    }
  }
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery
        .of(context)
        .size
        .height;
    final screenWidth = MediaQuery
        .of(context)
        .size
        .width;

    if (!isCameraInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildShimmerLoading(),
      );
    }

    return WillPopScope(
        onWillPop: () async {
          _handleCloseButton();
          return false;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
        onScaleUpdate: _handleScaleUpdate,
        onTapUp: _handleTapToFocus,
        onHorizontalDragEnd: _handleHorizontalDragEnd,
        child: Stack(
          children: [
            // FULL SCREEN CAMERA PREVIEW WITH FILTER
            Positioned.fill(
              child: Stack(
                children: [
                  // හදපු - Camera preview with color filter
                  ColorFiltered(
                    colorFilter: selectedFilter?.colorFilter ??
                        const ColorFilter.mode(
                            Colors.transparent, BlendMode.multiply),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final screenW = constraints.maxWidth;
                        final screenH = constraints.maxHeight;

                        // Camera sensor size
                        final previewSize = _cameraController!.value.previewSize!;
                        final camW = previewSize.height;
                        final camH = previewSize.width;

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // ── FULLSCREEN camera - screen සම්පූර්ණයෙන් cover ──
                            SizedBox(
                              width: screenW,
                              height: screenH,
                              child: FittedBox(
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: camW,
                                  height: camH,
                                  child: CameraPreview(_cameraController!),
                                ),
                              ),
                            ),


                          ],
                        );
                      },
                    ),
                  ),
                  if (beautyLevel > 0)
                    Positioned.fill(
                      child: _buildBeautyOverlay(),
                    ),

                  if (_focusPoint != null)
                    Positioned(
                      left: _focusPoint!.dx - 40,
                      top: _focusPoint!.dy - 40,
                      child: FadeTransition(
                        opacity: _focusAnimationController,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.yellow, width: 2),
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                      ),
                    ),

                  if (isCountingDown)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.7),
                        child: Stack(
                          children: [
                            Center(
                              child: countdown > 0
                                  ? TweenAnimationBuilder<double>(
                                key: ValueKey(countdown),
                                tween: Tween(begin: 1.2, end: 1.0),
                                duration: const Duration(milliseconds: 300),
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: Text(
                                      '$countdown',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 120,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            color: const Color(0xFFFF3B5C)
                                                .withOpacity(0.5),
                                            blurRadius: 20,
                                            offset: const Offset(0, 0),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                                  : TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.8, end: 1.2),
                                duration: const Duration(milliseconds: 300),
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: Text(
                                      selectedDuration == 'Photo' ? '📸' : '🎬',
                                      style: const TextStyle(
                                        fontSize: 100,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 60,
                              right: 20,
                              child: GestureDetector(
                                onTap: _cancelCountdown,
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.5),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 100,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Text(
                                  countdown > 0
                                      ? 'Get ready to ${selectedDuration ==
                                      'Photo' ? 'pose' : 'record'}...'
                                      : '${selectedDuration == 'Photo'
                                      ? 'Smile!'
                                      : 'Action!'}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 🎯 FIX: Top Bar with improved Close button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 45, 16, 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 🎯 FIX: Close button එක
                    GestureDetector(
                      onTap: () {
                        debugPrint('🚪 Close button pressed');

                        // 🛑 STEP 1: Stop recording if active
                        if (isRecording) {
                          debugPrint('⏹️ Stopping active recording...');
                          handleStopRecording();
                        }

                        // 🛑 STEP 2: Stop audio if playing
                        if (isAudioPlaying) {
                          debugPrint('🔇 Stopping audio...');
                          _audioPlayer.stop();
                        }

                        // 🛑 STEP 3: Dispose camera safely
                        if (_cameraController != null) {
                          try {
                            debugPrint('📷 Disposing camera...');
                            _cameraController!.dispose();
                            debugPrint('✅ Camera disposed');
                          } catch (e) {
                            debugPrint(
                                '⚠️ Camera disposal error (ignored): $e');
                          }
                        }

                        // ✅ STEP 4: Navigate to MainScreen (FIXED!)
                        if (mounted) {
                          debugPrint('🏠 Navigating to MainScreen...');
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                                builder: (context) => const MainScreen()),
                          );
                        }
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                            Icons.close, color: Colors.white, size: 20),
                      ),
                    ),

                    // 🎵 Add Sound Button
                    GestureDetector(
                      onTap: () async {
                        await _selectAudio();
                        // Test button - debug කරන්න
                        Future.delayed(const Duration(seconds: 2), () {
                          if (selectedAudio != null) _testAudioPlayback();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: selectedAudio != null
                              ? const Color(0xFFFF3B5C)
                              : Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              selectedAudio != null ? Icons.music_note : Icons
                                  .music_note_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              selectedAudio != null
                                  ? 'Change Sound'
                                  : 'Add Sound',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 36),
                  ],
                ),
              ),
            ),

            if (selectedAudio != null)
              Positioned(
                top: 95,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isAudioPlaying)
                          AnimatedBuilder(
                            animation: _waveformController,
                            builder: (context, child) {
                              return Row(
                                children: List.generate(4, (index) {
                                  return Container(
                                    width: 2.5,
                                    height: 10 + (math.sin(
                                        _waveformController.value * math.pi +
                                            index) * 5),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF3B5C),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                        if (isAudioPlaying) const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                selectedAudio!.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                selectedAudio!.artist,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedAudio = null;
                              isAudioPlaying = false;
                            });
                            _audioPlayer.stop();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                                Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // RIGHT SIDE CONTROLS
            Positioned(
              right: 12,
              top: screenHeight * 0.18,
              child: Column(
                children: [
                  _buildCompactRightButton(
                      Icons.cameraswitch, handleFlipCamera, 'Flip'),
                  const SizedBox(height: 16),
                  _buildCompactRightButton(
                      getFlashIcon(), handleFlashToggle, 'Flash'),
                  const SizedBox(height: 16),
                  _buildCompactRightButton(
                    Icons.timer_outlined,
                    _toggleTimer,
                    timerSeconds == 0 ? 'Timer' : '${timerSeconds}s',
                  ),
                  if (selectedDuration != 'Photo') ...[
                    const SizedBox(height: 16),
                    _buildCompactRightButton(Icons.speed, _toggleSpeedSelector,
                        '${recordingSpeed}x'),
                  ],
                  const SizedBox(height: 16),
                  _buildCompactRightButton(
                      Icons.face_retouching_natural, _toggleBeautySlider,
                      'Beauty'),
                  const SizedBox(height: 16),
                  _buildCompactRightButton(
                    Icons.filter_vintage,
                    _toggleFilterPanel,
                    selectedFilter?.name ?? 'Filter',
                  ),
                ],
              ),
            ),

            if (showTimerSelector)
              Positioned(
                right: 75,
                top: screenHeight * 0.18 + 90,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildTimerOption(0, 'OFF', 'No timer'),
                      const Divider(color: Colors.white24, height: 1),
                      _buildTimerOption(3, '3s', 'Quick timer'),
                      const Divider(color: Colors.white24, height: 1),
                      _buildTimerOption(10, '10s', 'Long timer'),
                    ],
                  ),
                ),
              ),

            if (showBeautySlider)
              Positioned(
                right: 75,
                top: screenHeight * 0.18 + 240,
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Beauty',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Slider(
                        value: beautyLevel,
                        onChanged: (value) {
                          setState(() {
                            beautyLevel = value;
                          });
                        },
                        activeColor: const Color(0xFFFF3B5C),
                        inactiveColor: Colors.white24,
                      ),
                      Text(
                        '${(beautyLevel * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (showSpeedSelector && selectedDuration != 'Photo')
              Positioned(
                right: 75,
                top: screenHeight * 0.18 + 140,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildSpeedOption(0.3, '🐢 0.3x', 'Ultra Slow'),
                      const Divider(color: Colors.white24, height: 1),
                      _buildSpeedOption(0.5, '🐌 0.5x', 'Slow'),
                      const Divider(color: Colors.white24, height: 1),
                      _buildSpeedOption(1.0, '⚡ 1x', 'Normal'),
                      const Divider(color: Colors.white24, height: 1),
                      _buildSpeedOption(2.0, '🚀 2x', 'Fast'),
                      const Divider(color: Colors.white24, height: 1),
                      _buildSpeedOption(3.0, '💨 3x', 'Ultra Fast'),
                    ],
                  ),
                ),
              ),

            if (showFilterPanel)
              Positioned(
                bottom: 180,
                left: 0,
                right: 0,
                child: _buildFilterPanel(),
              ),

            // BOTTOM BAR
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.75),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
                padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery
                    .of(context)
                    .padding
                    .bottom + 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (recordedClips.isNotEmpty && isRecording)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B5C).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                  Icons.video_library, color: Colors.white,
                                  size: 16),
                              const SizedBox(width: 7),
                              Text(
                                '${recordedClips.length} clip${recordedClips
                                    .length > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              if (recordedClips.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: _deleteLastClip,
                                  child: const Icon(
                                      Icons.delete_outline, color: Colors.white,
                                      size: 16),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                    _buildModernTabSelector(),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildBottomIconButtonWithPreview(
                          icon: Icons.emoji_emotions_outlined,
                          label: 'Effect',
                          onTap: _openFaceEffects,
                          thumbnail: latestStickerThumbnail,
                          isLoading: false,
                        ),

                        Column(
                          children: [
                            _buildRecordButton(),
                            if (isRecording && selectedDuration != 'Photo')
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: GestureDetector(
                                  onTap: handlePauseResumeRecording,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isPaused ? Colors.green : Colors
                                          .orange,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isPaused ? Icons.play_arrow : Icons
                                              .pause,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          isPaused ? 'Resume' : 'Pause',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        _buildBottomIconButtonWithPreview(
                          icon: Icons.image_outlined,
                          label: 'Upload',
                          onTap: _openGalleryPicker,
                          thumbnail: latestImageThumbnail,
                          isLoading: isLoadingGalleryPreview,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Mode Badge
            Positioned(
              top: 140,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: selectedDuration == 'Photo'
                          ? const Color(0xFF10B981).withOpacity(0.85)
                          : const Color(0xFFFF3B5C).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selectedDuration == 'Photo' ? Icons.camera_alt : Icons
                              .videocam,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          selectedDuration.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (isRecording && recordingSpeed != 1.0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.speed, color: Colors.white,
                                size: 12),
                            const SizedBox(width: 5),
                            Text(
                              '${recordingSpeed}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (selectedFilter != null && selectedFilter!.id != 'none')
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: selectedFilter!.thumbnailColor.withOpacity(
                              0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(selectedFilter!.icon, color: Colors.white,
                                size: 12),
                            const SizedBox(width: 5),
                            Text(
                              selectedFilter!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildModernTabSelector() {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: durations.length,
        itemBuilder: (context, index) {
          final duration = durations[index];
          final isSelected = selectedDuration == duration;
          final hPad = isSelected ? 28.0 : 20.0;

          return GestureDetector(
            onTap: () => handleDurationSelection(duration),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 10),
              decoration: isSelected
                  ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              )
                  : null,
              child: Center(
                child: Text(
                  duration,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: isSelected ? 15 : 14,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactRightButton(IconData icon, VoidCallback onTap,
      String label) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerOption(int seconds, String mainLabel, String subLabel) {
    final isSelected = timerSeconds == seconds;
    return GestureDetector(
      onTap: () => _setTimerDuration(seconds),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
        child: Row(
          children: [
            Icon(
              seconds == 0 ? Icons.timer_off : Icons.timer,
              color: isSelected ? const Color(0xFFFF3B5C) : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mainLabel,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFFF3B5C) : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight
                        .normal,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subLabel,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedOption(double speed, String emoji, String label) {
    final isSelected = recordingSpeed == speed;
    return GestureDetector(
      onTap: () => _setRecordingSpeed(speed),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
        child: Row(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFFF3B5C) : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight
                        .normal,
                    fontSize: 13,
                  ),
                ),
                Text(
                  speed < 1.0 ? 'Slow motion effect' : speed > 1.0
                      ? 'Time-lapse effect'
                      : 'Regular speed',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomIconButtonWithPreview({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Uint8List? thumbnail,
    required bool isLoading,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2.5,
              ),
            ),
            child: isLoading
                ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
                : thumbnail != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                thumbnail,
                fit: BoxFit.cover,
                width: 60,
                height: 60,
              ),
            )
                : Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: timerSeconds > 0 && !isRecording ? _startCountdown : (isRecording
          ? handleStopRecording
          : handleRecordPress),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.92).animate(
            _recordScaleController),
        child: SizedBox(
          width: 75,
          height: 75,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (selectedDuration != 'Photo' && isRecording)
                SizedBox(
                  width: 75,
                  height: 75,
                  child: CustomPaint(
                    painter: CircularProgressPainter(
                      progress: recordingTime / getMaxDuration(),
                      color: const Color(0xFFFF3B5C),
                      backgroundColor: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isRecording ? 28 : 58,
                        height: isRecording ? 28 : 58,
                        decoration: BoxDecoration(
                          color: selectedDuration == 'Photo'
                              ? Colors.white
                              : const Color(0xFFFF3B5C),
                          borderRadius: isRecording
                              ? BorderRadius.circular(5)
                              : BorderRadius.circular(29),
                        ),
                      ),
                      if (selectedDuration != 'Photo' && isRecording)
                        Text(
                          formatTime(recordingTime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
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
    );
  }

  void _openTextPostCreator() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TextPostScreen(),
      ),).then((imagePath) {
      if (imagePath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Text post created: $imagePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  // Document 3 - Step 1: Audio Pre-processing
// Record button එබූ සැනින් sync වෙන්න audio buffer කරගන්නවා
  Future<void> _preBufferAudio() async {
    if (selectedAudio == null) {
      _isAudioBuffered = false;
      _bufferedAudioPath = null;
      return;
    }

    try {
      if (selectedAudio!.localPath != null) {
        final file = File(selectedAudio!.localPath!);
        if (await file.exists()) {
          _bufferedAudioPath = selectedAudio!.localPath;
          _isAudioBuffered = true;
          debugPrint('✅ Audio ready (local): $_bufferedAudioPath');
          return; // ✅ ဒီမှာ stop - setSource/seek call කරන්නෙ නෑ
        }
      }

      // Local නැත්නම් URL path save කරන්න පමණයි
      _bufferedAudioPath = selectedAudio!.audioUrl;
      _isAudioBuffered = true;
      debugPrint('✅ Audio path saved (url): $_bufferedAudioPath');

    } catch (e) {
      debugPrint('⚠️ Audio pre-buffer error: $e');
      _isAudioBuffered = false;
      _bufferedAudioPath = null;
    }
  }
  // ─── Method 1: Inverse Audio Rate Calculator ───────────────────────────────
// recordingSpeed 0.5x → audio 2.0x | recordingSpeed 2.0x → audio 0.5x
  double _getInverseAudioRate() {
    if (recordingSpeed == 1.0) return 1.0;

    // Inverse formula: audioRate = 1 / recordingSpeed
    final inverseRate = 1.0 / recordingSpeed;

    // Clamp between 0.25x - 4.0x (audioplayers limit)
    return inverseRate.clamp(0.25, 4.0);
  }
// ─── Method 2: Audio Speed + Pitch Correction ──────────────────────────────
// Playback rate වෙනස් කරනවා, හැබැයි pitch (ස්වරය) නොවෙනස්ව
  Future<void> _setAudioSpeedWithPitchCorrection(double rate) async {
    try {
      final safeRate = rate.clamp(0.5, 2.0);
      await _audioPlayer.setPlaybackRate(safeRate);
      debugPrint('🎵 Audio rate set to ${safeRate}x');
    } catch (e) {
      debugPrint('⚠️ Audio rate error: $e — falling back to 1.0x');
      try {
        await _audioPlayer.setPlaybackRate(1.0);
      } catch (_) {}
    }
  }
  // ─── Filter Matrix Helper ───────────────────────────────────────────────────
// Camera filter → List<double> matrix convert කරනවා
  List<double>? _getColorFilterMatrix(CameraFilter filter) {
    if (filter.colorFilter == null) return null;

    // filters list එකෙන් id අනුව matrix return කරනවා
    switch (filter.id) {
      case 'vintage':
        return [0.9, 0.5, 0.1, 0, 0, 0.3, 0.8, 0.1, 0, 0, 0.2, 0.3, 0.5, 0, 0, 0, 0, 0, 1, 0];
      case 'cool':
        return [0.8, 0, 0, 0, 0, 0, 0.9, 0, 0, 0, 0.2, 0.2, 1.2, 0, 0, 0, 0, 0, 1, 0];
      case 'warm':
        return [1.2, 0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 0, 0.8, 0, 0, 0, 0, 0, 1, 0];
      case 'bw':
        return [0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0, 0, 0, 1, 0];
      case 'sepia':
        return [0.393, 0.769, 0.189, 0, 0, 0.349, 0.686, 0.168, 0, 0, 0.272, 0.534, 0.131, 0, 0, 0, 0, 0, 1, 0];
      case 'vibrant':
        return [1.4, 0, 0, 0, 0, 0, 1.4, 0, 0, 0, 0, 0, 1.4, 0, 0, 0, 0, 0, 1, 0];
      case 'dramatic':
        return [1.5, 0, 0, 0, -20, 0, 1.5, 0, 0, -20, 0, 0, 1.5, 0, -20, 0, 0, 0, 1, 0];
      case 'pastel':
        return [0.9, 0.1, 0.1, 0, 20, 0.1, 0.9, 0.1, 0, 20, 0.1, 0.1, 0.9, 0, 20, 0, 0, 0, 1, 0];
      case 'sunset':
        return [1.3, 0, 0, 0, 0, 0, 0.9, 0, 0, 0, 0, 0, 0.6, 0, 0, 0, 0, 0, 1, 0];
      case 'neon':
        return [1.6, 0, 0, 0, 0, 0, 1.3, 0.3, 0, 0, 0.3, 0, 1.6, 0, 0, 0, 0, 0, 1, 0];
      case 'arctic':
        return [0.7, 0.1, 0.2, 0, 10, 0.1, 0.9, 0.1, 0, 15, 0.2, 0.2, 1.3, 0, 20, 0, 0, 0, 1, 0];
      case 'golden':
        return [1.4, 0.2, 0, 0, 10, 0.2, 1.2, 0, 0, 5, 0, 0, 0.7, 0, 0, 0, 0, 0, 1, 0];
      case 'moonlight':
        return [0.6, 0.1, 0.2, 0, 5, 0.1, 0.7, 0.2, 0, 10, 0.2, 0.2, 0.9, 0, 15, 0, 0, 0, 1, 0];
      case 'cherry':
        return [1.2, 0.2, 0.2, 0, 10, 0.1, 0.9, 0.2, 0, 5, 0.2, 0.1, 0.8, 0, 0, 0, 0, 0, 1, 0];
      case 'ocean':
        return [0.6, 0.1, 0.1, 0, 0, 0.1, 0.8, 0.2, 0, 5, 0.2, 0.3, 1.1, 0, 10, 0, 0, 0, 1, 0];
      case 'autumn':
        return [1.3, 0.3, 0, 0, 0, 0.2, 1.0, 0, 0, 0, 0, 0, 0.6, 0, 0, 0, 0, 0, 1, 0];
      case 'retro':
        return [1.0, 0.3, 0.2, 0, 0, 0.2, 0.9, 0.2, 0, 0, 0.1, 0.1, 0.7, 0, 0, 0, 0, 0, 1, 0];
      case 'spring':
        return [0.9, 0.2, 0, 0, 15, 0.2, 1.1, 0.2, 0, 20, 0, 0.2, 0.9, 0, 15, 0, 0, 0, 1, 0];
      case 'lavender':
        return [1.0, 0.2, 0.3, 0, 10, 0.1, 0.8, 0.2, 0, 5, 0.3, 0.2, 1.1, 0, 15, 0, 0, 0, 1, 0];
      default:
        return null;
    }
  }

  Future<void> _requestAllPermissionsAtOnce() async {
    // Camera + Microphone + Gallery permissions එකවර request
    await Future.wait([
      PhotoManager.requestPermissionExtend(),
      Permission.camera.request(),
      Permission.microphone.request(),
    ]);

    // Permissions ඉවරවූ පසු camera initialize
    await _initializeCamera();
  }
  }

// ── TikTok-style top camera shape ──────────────────────────────────────────
// ── TikTok-style top camera notch ──────────────────────────────────────────
class _TikTokTopShapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final path = Path();

    // Top-left corner
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);

    // Right side curved inward
    path.quadraticBezierTo(
      size.width * 0.72, size.height * 0.2,
      size.width * 0.65, 0,
    );

    // Center notch (front camera bump)
    path.quadraticBezierTo(
      size.width * 0.58, size.height * 1.6,
      size.width * 0.5, size.height * 1.7,
    );
    path.quadraticBezierTo(
      size.width * 0.42, size.height * 1.6,
      size.width * 0.35, 0,
    );

    // Left side curved inward
    path.quadraticBezierTo(
      size.width * 0.28, size.height * 0.2,
      0, size.height,
    );

    path.close();
    canvas.drawPath(path, paint);

    // Front camera lens dot
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 1.15),
      5.0,
      Paint()..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(_TikTokTopShapePainter oldDelegate) => false;
}

class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class VideoClip {
  final String path;
  final int duration;
  final String timestamp;
  final double speed;

  VideoClip({
    required this.path,
    required this.duration,
    required this.timestamp,
    this.speed = 1.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'duration': duration,
      'timestamp': timestamp,
      'speed': speed,
    };
  }

  factory VideoClip.fromJson(Map<String, dynamic> json) {
    return VideoClip(
      path: json['path'],
      duration: json['duration'],
      timestamp: json['timestamp'],
      speed: json['speed'] ?? 1.0,
    );
  }
}