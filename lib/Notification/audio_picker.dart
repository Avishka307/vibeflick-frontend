import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../audio_extraction_service.dart';
import '../database_helper.dart';
import '../firebase_service.dart';
import '../supabase_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
class AudioPickerImproved extends StatefulWidget {
  final Function(AudioTrackEnhanced?) onAudioSelected;

  const AudioPickerImproved({
    Key? key,
    required this.onAudioSelected,
  }) : super(key: key);

  @override
  State<AudioPickerImproved> createState() => _AudioPickerImprovedState();
}

class _AudioPickerImprovedState extends State<AudioPickerImproved> with TickerProviderStateMixin {
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? currentlyPlaying;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Audio trimming
  AudioTrackEnhanced? selectedTrackForTrim;
  double trimStart = 0.0;
  double trimEnd = 15.0;
  bool showTrimDialog = false;

  // Upload limit tracking (දවසකට 3 uploads)
  int _todayUploadCount = 0;
  String? _lastUploadDate;
  static const int _maxDailyUploads = 3;

  // Volume control
  double previewVolume = 0.7;

  // Loading states
  Map<String, bool> loadingStates = {};
  Map<String, String> cachedPaths = {};

  // Search
  String searchQuery = '';
  List<AudioTrackEnhanced> filteredSongs = [];

  // Waveform animation
  late AnimationController _waveformController;

  // Upload
  List<AudioTrackEnhanced> uploadedSongs = [];
  bool isUploading = false;
  bool isExtracting = false;
  String uploadProgress = '';
  double uploadProgressPercent = 0.0; // NEW: Progress percentage

  // Favorites
  Set<String> favoritedIds = {};

// 🆕 NEW: Internet connectivity tracking එකතු කරන්න මෙතනට
  bool _hasInternetConnection = true;
  bool _showNoInternetToast = false;

  // Recently added highlight
  String? recentlyAddedId;
  Timer? _highlightTimer;

  // Firebase/Firestore songs (For You tab එකේ පෙන්වන්න)
  List<AudioTrackEnhanced> firestoreSongs = [];
  bool isLoadingFirestoreSongs = false;

  // Supabase storage එකෙන් direct files (For You tab එකේ පෙන්වන්න)
  List<AudioTrackEnhanced> supabaseSongs = [];
  bool isLoadingSupabaseSongs = false;

  // Combined songs (Firestore + Supabase)
  List<AudioTrackEnhanced> allForYouSongs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 3, vsync: this); // 3 tabs only: For You, Favorites, Upload
    _searchController.addListener(_onSearchChanged);
    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )
      ..repeat(reverse: true);

    _previewPlayer.setVolume(previewVolume);

    // Firebase offline persistence enable කරන්න
    FirebaseService.enableOfflinePersistence();

    // දෙන්නම එකට load කරන්න - Firestore සහ Supabase
    _loadAllForYouSongs();
    _loadUploadedTracks();
    // ⭐ Favorites load කරන්න FIRST (local storage එකෙන්)
    _loadFavorites();
    // 🆕 Upload count load කරන්න
    _loadUploadCount();
  }

  // සින්දුවේ නමින් random color එකක් generate කරන්න
  Color _getColorForTrack(String trackId) {
    final hash = trackId.hashCode;
    final colors = [
      [const Color(0xFFFF3B5C), const Color(0xFFFF6B8A)],
      // Pink to Light Pink
      [const Color(0xFF6C63FF), const Color(0xFF9D95FF)],
      // Purple to Light Purple
      [const Color(0xFF00D4FF), const Color(0xFF4DFFFF)],
      // Cyan to Light Cyan
      [const Color(0xFFFF9500), const Color(0xFFFFB84D)],
      // Orange to Light Orange
      [const Color(0xFF00E676), const Color(0xFF4DFFAA)],
      // Green to Light Green
      [const Color(0xFFFF1744), const Color(0xFFFF5270)],
      // Red to Light Red
      [const Color(0xFF2196F3), const Color(0xFF64B5F6)],
      // Blue to Light Blue
      [const Color(0xFF9C27B0), const Color(0xFFBA68C8)],
      // Deep Purple to Light
      [const Color(0xFFFFD600), const Color(0xFFFFE54C)],
      // Yellow to Light Yellow
      [const Color(0xFF00BCD4), const Color(0xFF4DD0E1)],
      // Teal to Light Teal
    ];
    return colors[hash.abs() % colors.length][0];
  }

  // සින්දුවේ නමින් gradient colors generate කරන්න
  List<Color> _getGradientForTrack(String trackId) {
    final hash = trackId.hashCode;
    final gradients = [
      [const Color(0xFFFF3B5C), const Color(0xFFFF6B8A)],
      // Pink gradient
      [const Color(0xFF6C63FF), const Color(0xFF9D95FF)],
      // Purple gradient
      [const Color(0xFF00D4FF), const Color(0xFF4DFFFF)],
      // Cyan gradient
      [const Color(0xFFFF9500), const Color(0xFFFFB84D)],
      // Orange gradient
      [const Color(0xFF00E676), const Color(0xFF4DFFAA)],
      // Green gradient
      [const Color(0xFFFF1744), const Color(0xFFFF5270)],
      // Red gradient
      [const Color(0xFF2196F3), const Color(0xFF64B5F6)],
      // Blue gradient
      [const Color(0xFF9C27B0), const Color(0xFFBA68C8)],
      // Deep Purple gradient
      [const Color(0xFFFFD600), const Color(0xFFFFE54C)],
      // Yellow gradient
      [const Color(0xFF00BCD4), const Color(0xFF4DD0E1)],
      // Teal gradient
    ];
    return gradients[hash.abs() % gradients.length];
  }

  // සින්දුවේ නමින් random icon එකක් generate කරන්න
  IconData _getIconForTrack(String trackId) {
    final hash = trackId.hashCode;
    final icons = [
      Icons.headphones,
      Icons.music_note,
      Icons.audiotrack,
      Icons.album,
      Icons.queue_music,
      Icons.library_music,
      Icons.mic,
      Icons.piano,
      Icons.music_video,
      Icons.speaker,
    ];
    return icons[hash.abs() % icons.length];
  }

  // දෙන්නම එකට load කරන්න - Firestore සහ Supabase
  Future<void> _loadAllForYouSongs() async {
    setState(() {
      isLoadingFirestoreSongs = true;
      isLoadingSupabaseSongs = true;
    });

    // දෙන්නම parallel එකේ load කරන්න (වේගවත් කරන්න)
    await Future.wait([
      _loadFirestoreSongs(),
      _loadSupabaseSongs(),
    ]);

    // Combine කරලා For You list එක හදන්න
    _combineForYouSongs();

    setState(() {
      isLoadingFirestoreSongs = false;
      isLoadingSupabaseSongs = false;
    });
  }

  // Firestore සහ Supabase songs එකට combine කරන්න
  void _combineForYouSongs() {
    // Duplicate නැතුව combine කරන්න (audioUrl එක check කරලා)
    final Map<String, AudioTrackEnhanced> uniqueSongs = {};

    // පළමුව Firestore songs add කරන්න (priority)
    for (var song in firestoreSongs) {
      uniqueSongs[song.audioUrl] = song;
    }

    // ඊට පස්සේ Supabase songs add කරන්න (duplicate නම් skip)
    for (var song in supabaseSongs) {
      if (!uniqueSongs.containsKey(song.audioUrl)) {
        uniqueSongs[song.audioUrl] = song;
      }
    }

    setState(() {
      allForYouSongs = uniqueSongs.values.toList();
      _filterSongs();
    });

    print('🎵 Total For You songs: ${allForYouSongs
        .length} (Firestore: ${firestoreSongs.length}, Supabase: ${supabaseSongs
        .length})');
  }

// Supabase storage එකෙන් audio files load කරන්න (Progressive Loading)
  Future<void> _loadSupabaseSongs() async {
    print('🔍 DEBUG: Starting _loadSupabaseSongs...');

    try {
      final supabase = Supabase.instance.client;
      print('🔍 DEBUG: Supabase client initialized');

      // 'sounds' bucket එකෙන් සියලුම files list කරන්න
      print('🔍 DEBUG: Fetching files from sounds bucket...');
      final List<FileObject> files = await supabase
          .storage
          .from('sounds')
          .list();

      print('🔍 DEBUG: Files fetched. Total count: ${files.length}');
      print('🔍 DEBUG: Files list: ${files.map((f) => f.name).toList()}');

      // Progressive loading සඳහා temporary list එකක්
      List<AudioTrackEnhanced> loadedSongs = [];

      for (var file in files) {
        print('🔍 DEBUG: Processing file: ${file.name}');

        // Audio files පමණක් filter කරන්න
        if (file.name.endsWith('.mp3') ||
            file.name.endsWith('.wav') ||
            file.name.endsWith('.m4a') ||
            file.name.endsWith('.aac')) {
          print('🔍 DEBUG: File ${file.name} is an audio file');

          // Public URL එක ගන්න
          final String publicUrl = supabase
              .storage
              .from('sounds')
              .getPublicUrl(file.name);

          print('🔍 DEBUG: Public URL: $publicUrl');

          // File name එකෙන් title එක extract කරන්න
          final String fileName = path.basenameWithoutExtension(file.name);

          // Artist name එක extract කරන්න
          final String artistName = _extractArtistName(fileName);

          print('🎵 DEBUG: Extracted artist: $artistName');

          // Track object එක හදන්න (duration එක background එකේ load කරන්න පස්සේ)
          final track = AudioTrackEnhanced(
            id: 'supabase_${file.name}',
            title: _formatFileName(fileName),
            artist: artistName,
            duration: 180,
            // Default duration පළමුව
            coverUrl: 'https://via.placeholder.com/60',
            audioUrl: publicUrl,
            category: 'Supabase Library',
            hasLyrics: false,
          );

          loadedSongs.add(track);
          print('🔍 DEBUG: Track added: ${track.title} by ${track.artist}');

          // ⭐ එක song එකක් add වෙන ගමන් UI එක update කරන්න (Progressive Loading)
          setState(() {
            supabaseSongs = List.from(loadedSongs);
          });
          _combineForYouSongs(); // For You list එක update කරන්න

          // ✅ මෙහෙම කරන්න
          _getAudioDuration(publicUrl).then((duration) {
            if (!mounted) return;   // ← ADD: dispose check
            final index = loadedSongs.indexWhere((t) => t.id == track.id);
            if (index != -1) {
              loadedSongs[index] = track.copyWith(duration: duration);
              if (!mounted) return; // ← ADD: double check
              // ✅ Fix
              if (mounted) {  // ← ADD
                setState(() {
                  supabaseSongs = List.from(loadedSongs);
                });
                _combineForYouSongs();
              }
              debugPrint('⏱️ Updated duration for ${track.title}: $duration seconds');
            }
          }).catchError((e) {
            if (!mounted) return;   // ← ADD
            debugPrint('⚠️ Could not get duration for ${track.title}: $e');
          });
        } else {
          print('🔍 DEBUG: File ${file.name} is NOT an audio file - skipped');
        }
      }

      print('🔍 DEBUG: Total audio tracks loaded from Supabase: ${loadedSongs
          .length}');
    } catch (e, stackTrace) {
      print('❌ ERROR loading Supabase songs: $e');
      print('❌ Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Could not load library songs: ${e.toString()}'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Firestore එකෙන් audio metadata load කරන්න (Pagination සමග)
  Future<void> _loadFirestoreSongs() async {
    print('🔍 DEBUG: Starting _loadFirestoreSongs from Firestore...');

    setState(() {
      isLoadingFirestoreSongs = true;
    });

    try {
      // Firestore එකෙන් sounds load කරන්න (පළමු 20 ක් විතරයි)
      final soundsData = await FirebaseService.loadSoundsFromFirestore(
        limit: 20,
      );

      print('🔍 DEBUG: Loaded ${soundsData.length} sounds from Firestore');

      List<AudioTrackEnhanced> loadedSongs = [];

      for (var data in soundsData) {
        // Track object එක හදන්න
        final track = AudioTrackEnhanced(
          id: 'firestore_${data['id']}',
          title: data['title'] ?? 'Unknown Title',
          artist: data['artist'] ?? 'Unknown Artist',
          duration: data['duration'] ?? 180,
          coverUrl: 'https://via.placeholder.com/60',
          audioUrl: data['audioUrl'],
          // Supabase URL එකයි මෙතන තියෙන්නේ
          category: data['category'] ?? 'User Uploads',
          hasLyrics: false,
        );

        loadedSongs.add(track);
        print('🔍 DEBUG: Track added: ${track.title} by ${track.artist}');
      }

      print('🔍 DEBUG: Total audio tracks loaded: ${loadedSongs.length}');

      setState(() {
        firestoreSongs = loadedSongs;
        isLoadingFirestoreSongs = false;
        _filterSongs();
      });

      print('🔍 DEBUG: State updated. firestoreSongs count: ${firestoreSongs
          .length}');
    } catch (e, stackTrace) {
      print('❌ ERROR loading Firestore songs: $e');
      print('❌ Stack trace: $stackTrace');

      setState(() {
        isLoadingFirestoreSongs = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error loading songs: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // File name එකෙන් Artist නම extract කරන්න
  String _extractArtistName(String fileName) {
    // උදා: "Alex-Makemusic-Chill-Beat" -> "Alex Makemusic"
    // උදා: "Go_Funk-Bettercalls" -> "Go Funk"

    final parts = fileName.split(RegExp(r'[-_]'));

    if (parts.length >= 2) {
      // පළමු කොටස් දෙක Artist නම විදිහට ගන්න
      String artistName = '${parts[0]}';
      if (parts.length > 1 && parts[1].isNotEmpty) {
        artistName += ' ${parts[1]}';
      }
      return _formatText(artistName);
    }

    return 'Original Sound';
  }

  // File name එක readable format එකකට convert කරන්න
  String _formatFileName(String fileName) {
    // Replace hyphens and underscores with spaces
    String formatted = fileName.replaceAll('-', ' ').replaceAll('_', ' ');

    // Capitalize first letter of each word
    return formatted.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // Text එකක් ලස්සනට format කරන්න
  String _formatText(String text) {
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // Audio file එකේ සැබෑ duration එක ගන්න
  Future<int> _getAudioDuration(String audioUrl) async {
    final tempPlayer = AudioPlayer();
    try {
      // Timeout 10s - 30s නෙමෙයි
      await tempPlayer.setSourceUrl(audioUrl)
          .timeout(const Duration(seconds: 10));

      await Future.delayed(const Duration(milliseconds: 500));

      final duration = await tempPlayer.getDuration()
          .timeout(const Duration(seconds: 5));

      await tempPlayer.dispose();
      return duration?.inSeconds ?? 180;
    } catch (e) {
      debugPrint('! Could not get audio duration: $e');
      await tempPlayer.dispose();
      return 180;
    }
  }

  Future<void> _loadUploadedTracks() async {
    final tracks = await DatabaseHelper.instance.getAllUploadedTracks();
    setState(() {
      // Sort by most recent first (reverse chronological order)
      uploadedSongs = tracks.reversed.toList();
    });
  }

// Favorites load කරන්න (App එක open වෙද්දී)
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesList = prefs.getStringList('favorite_tracks') ?? [];

      setState(() {
        favoritedIds = favoritesList.toSet();
      });

      print('✅ Loaded ${favoritedIds.length} favorites from local storage');
    } catch (e) {
      print('⚠️ Error loading favorites: $e');
      setState(() {
        favoritedIds = {};
      });
    }
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _waveformController.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text.toLowerCase();
      _filterSongs();
    });
  }

  void _filterSongs() {
    final allSongs = [...allForYouSongs, ...uploadedSongs];

    if (searchQuery.isEmpty) {
      filteredSongs = allSongs;
    } else {
      filteredSongs = allSongs.where((song) {
        return song.title.toLowerCase().contains(searchQuery) ||
            song.artist.toLowerCase().contains(searchQuery) ||
            song.category.toLowerCase().contains(searchQuery);
      }).toList();
    }
  }

  Future<String?> _getCachedAudioPath(String url, String trackId) async {
    try {
      if (cachedPaths.containsKey(trackId)) {
        return cachedPaths[trackId];
      }

      setState(() {
        loadingStates[trackId] = true;
      });

      final fileInfo = await DefaultCacheManager().getFileFromCache(url);

      if (fileInfo != null) {
        setState(() {
          cachedPaths[trackId] = fileInfo.file.path;
          loadingStates[trackId] = false;
        });
        return fileInfo.file.path;
      }

      final file = await DefaultCacheManager().getSingleFile(url);

      setState(() {
        cachedPaths[trackId] = file.path;
        loadingStates[trackId] = false;
      });

      return file.path;
    } catch (e) {
      print('Error caching audio: $e');
      setState(() {
        loadingStates[trackId] = false;
      });
      return null;
    }
  }

  Future<void> _playPreview(AudioTrackEnhanced track) async {
    if (currentlyPlaying == track.id) {
      await _previewPlayer.stop();
      setState(() {
        currentlyPlaying = null;
      });
      return;
    }

    await _previewPlayer.stop();

    String? audioPath;
    if (track.localPath != null) {
      audioPath = track.localPath;
    } else {
      audioPath = await _getCachedAudioPath(track.audioUrl, track.id);
    }

    if (audioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to load audio'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _previewPlayer.play(DeviceFileSource(audioPath));
    setState(() {
      currentlyPlaying = track.id;
    });

    Future.delayed(const Duration(seconds: 15), () {
      if (currentlyPlaying == track.id) {
        _previewPlayer.stop();
        setState(() {
          currentlyPlaying = null;
        });
      }
    });
  }


// Favorites save කරන්න (Favorite toggle කරන වෙලාවෙම)
  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_tracks', favoritedIds.toList());

      print('✅ Saved ${favoritedIds.length} favorites to local storage');
    } catch (e) {
      print('⚠️ Error saving favorites: $e');
    }
  }

// Toggle favorite එක update කරන්න (පරණ _toggleFavorite method එක replace කරන්න)
  void _toggleFavorite(String trackId) {
    setState(() {
      if (favoritedIds.contains(trackId)) {
        favoritedIds.remove(trackId);
      } else {
        favoritedIds.add(trackId);
      }
    });

    // ⭐ Local storage එකේ save කරන්න (Firebase නැතුව)
    _saveFavorites();
  }

// 🆕 NEW: Internet connection තියෙනවද බලන්න (මෙතන දාන්න)
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        setState(() {
          _hasInternetConnection = true;
        });
        return true;
      }
    } catch (e) {
      setState(() {
        _hasInternetConnection = false;
      });
      _showNoInternetConnection();
      return false;
    }
    return false;
  }

// 🆕 NEW: "No Internet" message පෙන්වන්න (මෙතනත් දාන්න)
  void _showNoInternetConnection() {
    if (!_showNoInternetToast) {
      setState(() {
        _showNoInternetToast = true;
        _hasInternetConnection = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.wifi_off, color: Colors.white),
              SizedBox(width: 12),
              Text('No internet connection'),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(top: 50, left: 16, right: 16),
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showNoInternetToast = false;
          });
        }
      });
    }
  }

  List<AudioTrackEnhanced> _getFavoriteSongs() {
    final allSongs = [...allForYouSongs, ...uploadedSongs];
    return allSongs.where((song) => favoritedIds.contains(song.id)).toList();
  }

  void _showTrimDialog(AudioTrackEnhanced track) async {
    String? cachedPath;
    if (track.localPath != null) {
      cachedPath = track.localPath;
    } else {
      cachedPath = await _getCachedAudioPath(track.audioUrl, track.id);
    }

    if (cachedPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, loading audio...')),
      );
      return;
    }

    setState(() {
      selectedTrackForTrim = track.copyWith(localPath: cachedPath);
      trimStart = 0.0;
      trimEnd = track.duration > 30 ? 30.0 : track.duration.toDouble();
    });

    showDialog(
      context: context,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                backgroundColor: const Color(0xFF1A1A1A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                              Icons.content_cut, color: Color(0xFFFF3B5C)),
                          const SizedBox(width: 10),
                          const Text(
                            'Trim Audio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        track.title,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Stack(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(50, (index) {
                                final height = 20.0 + (index % 7) * 8.0;
                                final isInRange = (index / 50) >=
                                    (trimStart / track.duration) &&
                                    (index / 50) <= (trimEnd / track.duration);

                                return Expanded(
                                  child: Container(
                                    height: height,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: isInRange
                                          ? const Color(0xFFFF3B5C)
                                          : Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Start: ${_formatDuration(trimStart.toInt())}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Duration: ${_formatDuration((trimEnd - trimStart)
                                .toInt())}',
                            style: const TextStyle(
                              color: Color(0xFFFF3B5C),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'End: ${_formatDuration(trimEnd.toInt())}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      RangeSlider(
                        values: RangeValues(trimStart, trimEnd),
                        min: 0,
                        max: track.duration.toDouble(),
                        divisions: track.duration,
                        activeColor: const Color(0xFFFF3B5C),
                        inactiveColor: Colors.white24,
                        onChanged: (values) {
                          setDialogState(() {
                            setState(() {
                              trimStart = values.start;
                              trimEnd = values.end;
                            });
                          });
                        },
                      ),

                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8,
                        children: [
                          _buildQuickTrimButton('First 15s', () {
                            setDialogState(() {
                              setState(() {
                                trimStart = 0;
                                trimEnd =
                                    15.0.clamp(0, track.duration.toDouble());
                              });
                            });
                          }),
                          _buildQuickTrimButton('First 30s', () {
                            setDialogState(() {
                              setState(() {
                                trimStart = 0;
                                trimEnd =
                                    30.0.clamp(0, track.duration.toDouble());
                              });
                            });
                          }),
                          _buildQuickTrimButton('Middle 15s', () {
                            final middle = track.duration / 2;
                            setDialogState(() {
                              setState(() {
                                trimStart = (middle - 7.5).clamp(
                                    0, track.duration - 15);
                                trimEnd = (middle + 7.5).clamp(
                                    15, track.duration.toDouble());
                              });
                            });
                          }),
                          _buildQuickTrimButton('Full', () {
                            setDialogState(() {
                              setState(() {
                                trimStart = 0;
                                trimEnd = track.duration.toDouble();
                              });
                            });
                          }),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              final trimmedTrack = selectedTrackForTrim!
                                  .copyWith(
                                trimStart: trimStart,
                                trimEnd: trimEnd,
                              );
                              widget.onAudioSelected(trimmedTrack);
                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF3B5C),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Use This'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _buildQuickTrimButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(
        2, '0')}';
  }

  void _selectTrack(AudioTrackEnhanced track) async {
    _previewPlayer.stop();

    String? audioPath;
    if (track.localPath != null) {
      audioPath = track.localPath;
    } else {
      audioPath = await _getCachedAudioPath(track.audioUrl, track.id);
    }

    if (audioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to prepare audio. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final trackWithPath = track.copyWith(localPath: audioPath);
    widget.onAudioSelected(trackWithPath);
    Navigator.pop(context);
  }

  // Show success popup after extraction
  void _showSuccessPopup(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
    );

    // Auto close after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> _browseFiles() async {
    // 🔥 Check upload limit
    if (_todayUploadCount >= _maxDailyUploads) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Daily upload limit reached ($_maxDailyUploads uploads per day). Try again tomorrow!'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    try {
      setState(() {
        isUploading = true;
        isExtracting = false;
        uploadProgress = 'Opening file picker...';
        uploadProgressPercent = 0.0;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'mp4', 'mov', 'avi', 'mkv'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          isUploading = false;
          isExtracting = false;
          uploadProgress = '';
          uploadProgressPercent = 0.0;
        });
        return;
      }

      final file = result.files.first;
      final filePath = file.path!;
      final fileName = path.basenameWithoutExtension(file.name);
      final fileExtension = path.extension(file.name).toLowerCase();

      // Check if it's a video file
      final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv'];
      bool isVideo = videoExtensions.contains(fileExtension);

      String? finalAudioPath;
      int duration = 0;
      String sourceType = isVideo ? 'Extracted from Video' : 'Uploaded from Files';

      if (isVideo) {
        // Extract audio from video
        setState(() {
          isExtracting = true;
          uploadProgress = 'Extracting audio from video...';
          uploadProgressPercent = 10.0;
        });

        finalAudioPath = await AudioExtractionService.extractAudioFromVideo(
          filePath,
              (progress) {
            setState(() {
              uploadProgress = progress;
              uploadProgressPercent = 20.0; // Extraction phase 10-30%
            });
          },
        );

        if (finalAudioPath == null) {
          throw Exception('Failed to extract audio from video');
        }

        duration = await AudioExtractionService.getAudioDuration(finalAudioPath);

        setState(() {
          uploadProgressPercent = 30.0;
        });
      } else {
        // Copy audio file
        setState(() {
          uploadProgress = 'Copying audio file...';
          uploadProgressPercent = 20.0;
        });

        finalAudioPath = await AudioExtractionService.copyAudioFile(filePath);

        if (finalAudioPath == null) {
          throw Exception('Failed to copy audio file');
        }

        duration = await AudioExtractionService.getAudioDuration(finalAudioPath);

        setState(() {
          uploadProgressPercent = 30.0;
        });
      }

      setState(() {
        uploadProgress = 'Uploading to cloud storage...';
        uploadProgressPercent = 40.0;
      });

      // 🆕 Internet check කරන්න upload කරන්න කලින්
      final hasInternet = await _checkInternetConnection();
      if (!hasInternet) {
        throw Exception('No internet connection. Please check your network.');
      }

      // Upload to Supabase Storage
      final supabaseUrl = await SupabaseService.uploadAudioToSupabase(
        filePath: finalAudioPath,
        fileName: file.name,
        onProgress: (progress) {
          setState(() {
            uploadProgress = 'Uploading: ${progress.toInt()}%';
            uploadProgressPercent = 40.0 + (progress * 0.4); // Upload phase 40-80%
          });
        },
      );

      if (supabaseUrl == null) {
        throw Exception('Failed to upload audio to Supabase');
      }

      setState(() {
        uploadProgress = 'Saving metadata...';
        uploadProgressPercent = 85.0;
      });

      // Extract artist name
      final artistName = _extractArtistName(fileName);

      // Save metadata to Firebase Firestore
      final firestoreDocId = await FirebaseService.saveSoundMetadata(
        title: fileName,
        supabaseAudioUrl: supabaseUrl,
        artist: artistName,
        duration: duration > 0 ? duration : 60,
      );

      if (firestoreDocId == null) {
        throw Exception('Failed to save metadata to Firestore');
      }

      setState(() {
        uploadProgress = 'Almost done...';
        uploadProgressPercent = 95.0;
      });

      // 🔥 FIX: Create track object BEFORE using it
      final track = AudioTrackEnhanced(
        id: 'uploaded_${DateTime.now().millisecondsSinceEpoch}',
        title: fileName,
        artist: artistName,
        duration: duration > 0 ? duration : 60,
        coverUrl: 'https://via.placeholder.com/60',
        audioUrl: supabaseUrl,
        category: 'User Uploads',
        localPath: finalAudioPath,
        sourceType: sourceType,
      );

      // Save to local database (optional)
      await DatabaseHelper.instance.insertTrack(track);

      // Reload Firestore songs to show the new upload
      await _loadAllForYouSongs();
      await _loadUploadedTracks();

      // 🔥 FIX: Upload success වුනාම count එක increment කරන්න (track create කරලා පස්සේ)
      await _incrementUploadCount();

      setState(() {
        isUploading = false;
        isExtracting = false;
        uploadProgress = '';
        uploadProgressPercent = 100.0;
        recentlyAddedId = track.id;
      });

      // Switch to For You tab to see the uploaded song
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _tabController.animateTo(0); // For You tab is index 0
        }
      });

      // Show success popup
      _showSuccessPopup(isVideo
          ? 'Sound Extracted & Uploaded!'
          : 'Audio Uploaded Successfully!');

      // Highlight the newly added track for 2 seconds
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            recentlyAddedId = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        isUploading = false;
        isExtracting = false;
        uploadProgress = '';
        uploadProgressPercent = 0.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Rename uploaded track
  Future<void> _renameTrack(AudioTrackEnhanced track) async {
    final controller = TextEditingController(text: track.title);

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Rename Track',
              style: TextStyle(color: Colors.white),
            ),
            content: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter new name',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFFF3B5C)),
                ),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newName = controller.text.trim();
                  if (newName.isNotEmpty && newName != track.title) {
                    final updatedTrack = track.copyWith(title: newName);
                    await DatabaseHelper.instance.updateTrack(updatedTrack);
                    await _loadUploadedTracks();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Track renamed'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B5C),
                ),
                child: const Text('Rename'),
              ),
            ],
          ),
    );
  }

  // Delete uploaded track
  Future<void> _deleteUploadedTrack(AudioTrackEnhanced track) async {
    try {
      // Delete from database
      await DatabaseHelper.instance.deleteTrack(track.id);

      // Delete file from storage
      if (track.localPath != null) {
        final file = File(track.localPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Reload tracks
      await _loadUploadedTracks();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ Track deleted'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error deleting: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery
          .of(context)
          .size
          .height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            _previewPlayer.stop();
                            Navigator.pop(context);
                          },
                        ),
                        const Text(
                          'Add Sound',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            widget.onAudioSelected(null);
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'No Sound',
                            style: TextStyle(
                              color: Color(0xFFFF3B5C),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search songs, artists...',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5)),
                      prefixIcon: Icon(
                          Icons.search, color: Colors.white.withOpacity(0.5)),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),

              // Volume Control
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                        Icons.volume_down, color: Colors.white70, size: 20),
                    Expanded(
                      child: Slider(
                        value: previewVolume,
                        onChanged: (value) {
                          setState(() {
                            previewVolume = value;
                          });
                          _previewPlayer.setVolume(value);
                        },
                        activeColor: const Color(0xFFFF3B5C),
                        inactiveColor: Colors.white24,
                      ),
                    ),
                    const Icon(
                        Icons.volume_up, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${(previewVolume * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Tabs (Only 3 tabs now: For You, Favorites, Upload)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: const Color(0xFFFF3B5C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.6),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  tabs: const [
                    Tab(text: 'For You'),
                    Tab(text: 'Favorites'),
                    Tab(text: 'Upload'),
                  ],
                ),
              ),

              // Track List
              Expanded(
                child: searchQuery.isNotEmpty
                    ? _buildSearchResults()
                    : TabBarView(
                  controller: _tabController,
                  children: [
                    // For You tab - දෙන්නම පෙන්වන්න (Firestore + Supabase)
                    (isLoadingFirestoreSongs || isLoadingSupabaseSongs)
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: Color(0xFFFF3B5C),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading library...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${allForYouSongs.length} songs found',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                        : _buildTrackList(allForYouSongs),
                    // Favorites tab
                    _buildTrackList(_getFavoriteSongs()),
                    // Upload tab
                    _buildUploadTab(),
                  ],
                ),
              ),
            ],
          ),

          // Upload/Extraction progress overlay with progress bar
          if (isUploading || isExtracting)
            Container(
              color: Colors.black.withOpacity(0.85),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated icon
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1000),
                        builder: (context, double value, child) {
                          return Transform.scale(
                            scale: 0.8 + (value * 0.2),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B5C).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.cloud_upload,
                                color: Color(0xFFFF3B5C),
                                size: 40,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: uploadProgressPercent / 100,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFF3B5C),
                          ),
                          minHeight: 8,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Progress percentage
                      Text(
                        '${uploadProgressPercent.toInt()}%',
                        style: const TextStyle(
                          color: Color(0xFFFF3B5C),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        uploadProgress,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (filteredSongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration for no results
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 50,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No results found',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching with different keywords',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return _buildTrackList(filteredSongs);
  }

  Widget _buildTrackList(List<AudioTrackEnhanced> tracks) {
    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.music_off,
                size: 50,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No songs yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tabController.index == 1
                  ? 'Favorite songs will appear here'
                  : 'Add some music to get started',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isPlaying = currentlyPlaying == track.id;
        final isLoading = loadingStates[track.id] ?? false;
        final isUploaded = track.category == 'Uploaded';
        final isFavorited = favoritedIds.contains(track.id);
        final isRecentlyAdded = track.id == recentlyAddedId;

        return GestureDetector(
          onTap: () =>
          track.isSoundEffect
              ? _selectTrack(track)
              : _showTrimDialog(track),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isRecentlyAdded
                  ? const Color(0xFFFF3B5C).withOpacity(0.25)
                  : isPlaying
                  ? const Color(0xFFFF3B5C).withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isRecentlyAdded
                    ? const Color(0xFFFF3B5C)
                    : isPlaying
                    ? const Color(0xFFFF3B5C)
                    : Colors.transparent,
                width: isRecentlyAdded ? 2 : 1.5,
              ),
            ),
            child: Row(
              children: [
                // Album Art with Gradient and Icon
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: _getGradientForTrack(track.id),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _getColorForTrack(track.id).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isLoading
                          ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                          : Icon(
                        _getIconForTrack(track.id),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    if (isPlaying && !isLoading)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _waveformController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: WaveformPainter(
                                animation: _waveformController.value,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // Track Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              track.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (track.hasLyrics)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B5C).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'LYRICS',
                                style: TextStyle(
                                  color: Color(0xFFFF3B5C),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            track.artist,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            ' • ${_formatDuration(track.duration)}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      // Source label
                      if (track.sourceType != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                track.sourceType == 'Extracted from Video'
                                    ? Icons.video_library
                                    : Icons.upload_file,
                                size: 12,
                                color: Colors.white.withOpacity(0.4),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                track.sourceType!,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (track.hasLyrics && track.lyrics != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            track.lyrics!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),

                // Favorite button (heart icon)
                if (!isUploaded)
                  GestureDetector(
                    onTap: () => _toggleFavorite(track.id),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        isFavorited ? Icons.favorite : Icons.favorite_border,
                        color: isFavorited ? Colors.red : Colors.white
                            .withOpacity(0.5),
                        size: 20,
                      ),
                    ),
                  ),

                // Play Preview Button
                GestureDetector(
                  onTap: () => _playPreview(track),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? const Color(0xFFFF3B5C)
                          : Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Use/Trim/Rename/Delete Button
                if (isUploaded)
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _renameTrack(track),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _deleteUploadedTrack(track),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  GestureDetector(
                    onTap: () =>
                    track.isSoundEffect
                        ? _selectTrack(track)
                        : _showTrimDialog(track),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B5C).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        track.isSoundEffect ? Icons.check : Icons.content_cut,
                        color: const Color(0xFFFF3B5C),
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadTab() {
    // 🔥 Check if upload limit reached
    final bool limitReached = _todayUploadCount >= _maxDailyUploads;

    return Column(
      children: [
        // 🔥 Upload section - Always visible at top
        Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Illustration icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: limitReached
                      ? Colors.orange.withOpacity(0.1)
                      : const Color(0xFFFF3B5C).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  limitReached ? Icons.block : Icons.cloud_upload_outlined,
                  color: limitReached ? Colors.orange : const Color(0xFFFF3B5C),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),

              // Upload count indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: limitReached
                      ? Colors.orange.withOpacity(0.15)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: limitReached ? Colors.orange : Colors.white.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  limitReached
                      ? 'Daily limit reached ($_todayUploadCount/$_maxDailyUploads)'
                      : '$_todayUploadCount / $_maxDailyUploads uploads today',
                  style: TextStyle(
                    color: limitReached ? Colors.orange : Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Upload button
              ElevatedButton.icon(
                onPressed: limitReached ? null : _browseFiles,
                icon: const Icon(Icons.add),
                label: Text(limitReached ? 'Limit Reached' : 'Browse Files'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: limitReached ? Colors.grey : const Color(0xFFFF3B5C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: limitReached ? 0 : 4,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),

              if (limitReached)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Try again tomorrow!',
                    style: TextStyle(
                      color: Colors.orange.withOpacity(0.8),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              if (!limitReached)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Audio: MP3, WAV, M4A, AAC • Video: MP4, MOV, AVI, MKV',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),

        // Divider
        if (uploadedSongs.isNotEmpty)
          Divider(
            color: Colors.white.withOpacity(0.1),
            thickness: 1,
            height: 1,
          ),

        // 🔥 Uploaded songs list
        Expanded(
          child: uploadedSongs.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.music_note,
                  size: 60,
                  color: Colors.white.withOpacity(0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  'No uploaded sounds yet',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'Your Uploads (${uploadedSongs.length})',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: _buildTrackList(uploadedSongs),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // දවසේ upload count එක load කරන්න
  Future<void> _loadUploadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toString().split(
          ' ')[0]; // YYYY-MM-DD format

      _lastUploadDate = prefs.getString('last_upload_date');

      if (_lastUploadDate == today) {
        // අද දවසේම uploads තියෙනවා
        setState(() {
          _todayUploadCount = prefs.getInt('today_upload_count') ?? 0;
        });
      } else {
        // අලුත් දවසක්, count එක reset කරන්න
        setState(() {
          _todayUploadCount = 0;
        });
        await prefs.setString('last_upload_date', today);
        await prefs.setInt('today_upload_count', 0);
      }

      print('📊 Today\'s upload count: $_todayUploadCount / $_maxDailyUploads');
    } catch (e) {
      print('⚠️ Error loading upload count: $e');
    }
  }

// 🔥 මෙතන දාන්න - _loadUploadCount එකට පස්සෙ
// Upload count එක increment කරන්න
  Future<void> _incrementUploadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toString().split(' ')[0];

      setState(() {
        _todayUploadCount++;
      });

      await prefs.setString('last_upload_date', today);
      await prefs.setInt('today_upload_count', _todayUploadCount);

      print(
          '📊 Upload count incremented: $_todayUploadCount / $_maxDailyUploads');
    } catch (e) {
      print('⚠️ Error incrementing upload count: $e');
    }
  }
}


// Waveform painter for visualizer
class WaveformPainter extends CustomPainter {
  final double animation;

  WaveformPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF3B5C).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final barCount = 5;
    final barWidth = size.width / (barCount * 2);

    for (int i = 0; i < barCount; i++) {
      final barHeight = size.height * (0.3 + (animation + i * 0.2) % 1.0 * 0.7);
      final x = i * barWidth * 2 + barWidth / 2;
      final rect = Rect.fromLTWH(
        x,
        size.height - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}

// Enhanced Audio Track model
class AudioTrackEnhanced {
  final String id;
  final String title;
  final String artist;
  final int duration;
  final String coverUrl;
  final String audioUrl;
  final String category;
  final bool hasLyrics;
  final String? lyrics;
  final bool isSoundEffect;
  final String? localPath;
  final double trimStart;
  final double trimEnd;
  final String? sourceType;

  AudioTrackEnhanced({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.coverUrl,
    required this.audioUrl,
    required this.category,
    this.hasLyrics = false,
    this.lyrics,
    this.isSoundEffect = false,
    this.localPath,
    this.trimStart = 0.0,
    double? trimEnd,
    this.sourceType,
  }) : trimEnd = trimEnd ?? duration.toDouble();

  String get durationString {
    final mins = duration ~/ 60;
    final secs = duration % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  AudioTrackEnhanced copyWith({
    String? id,
    String? title,
    String? artist,
    int? duration,
    String? coverUrl,
    String? audioUrl,
    String? category,
    bool? hasLyrics,
    String? lyrics,
    bool? isSoundEffect,
    String? localPath,
    double? trimStart,
    double? trimEnd,
    String? sourceType,
  }) {
    return AudioTrackEnhanced(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      duration: duration ?? this.duration,
      coverUrl: coverUrl ?? this.coverUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      category: category ?? this.category,
      hasLyrics: hasLyrics ?? this.hasLyrics,
      lyrics: lyrics ?? this.lyrics,
      isSoundEffect: isSoundEffect ?? this.isSoundEffect,
      localPath: localPath ?? this.localPath,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      sourceType: sourceType ?? this.sourceType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'duration': duration,
      'coverUrl': coverUrl,
      'audioUrl': audioUrl,
      'category': category,
      'hasLyrics': hasLyrics,
      'lyrics': lyrics,
      'isSoundEffect': isSoundEffect,
      'localPath': localPath,
      'trimStart': trimStart,
      'trimEnd': trimEnd,
      'sourceType': sourceType,
    };
  }

  factory AudioTrackEnhanced.fromJson(Map<String, dynamic> json) {
    return AudioTrackEnhanced(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      duration: json['duration'],
      coverUrl: json['coverUrl'],
      audioUrl: json['audioUrl'],
      category: json['category'],
      hasLyrics: json['hasLyrics'] ?? false,
      lyrics: json['lyrics'],
      isSoundEffect: json['isSoundEffect'] ?? false,
      localPath: json['localPath'],
      trimStart: json['trimStart'] ?? 0.0,
      trimEnd: json['trimEnd'],
      sourceType: json['sourceType'],
    );
  }
}