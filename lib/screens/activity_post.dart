import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_vibe_flick/screens/text_edit_bottom_sheet.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mime/mime.dart';
import 'dart:math' as math;
import '../VideoEditing/effect_bottom_sheet.dart';
import 'media_upload_helper.dart';
import 'tag_friends_screen.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'dart:io' as io;
// Import the bottom sheets
import 'bottom_sheet_who_can_view.dart';
import 'bottom_sheet_more_options.dart';
import 'package:video_trimmer/video_trimmer.dart'; // Add this import
class PostActivity extends StatefulWidget {
  final List<String>? selectedMedia;
  final String? mediaType;
  final bool isVideo;
  final File mediaFile;
  // ── අලුතින් add කරන parameters ──────────────
  final List<String> allMediaPaths;     // සියලු media paths
  final List<bool> allMediaIsVideo;     // ඒවායේ video/image status
  final List<double>? activeFilterMatrix;
  final List<Map<String, dynamic>> placedStickers;
  final List<RichTextOverlay> textOverlays;
  final String? selectedMusicPath;

  final String? selectedMusicId;
  final String? selectedMusicName;
  final String? selectedMusicAlbumArt;
  final double originalAudioVolume;
  final double musicVolume;
  final List<EffectLayer> effectLayers; // ✅ ADD
  final double trimStart;                 // ✅ NEW
  final double trimEnd;                   // ✅ NEW
  final String aspectRatio;              // ✅ NEW

  const PostActivity({
    super.key,
    this.selectedMedia,
    this.mediaType,
    required this.isVideo,
    required this.mediaFile,
    required String mediaPath,
    this.allMediaPaths = const [],      // default empty
    this.allMediaIsVideo = const [],
    // ── NEW ──
    this.activeFilterMatrix,
    this.placedStickers = const [],
    this.textOverlays = const [],
    this.selectedMusicPath,


    this.selectedMusicId,
    this.selectedMusicName,
    this.selectedMusicAlbumArt,
    this.originalAudioVolume = 1.0,
    this.musicVolume = 0.5,// default empty
    this.effectLayers = const [], // ✅ ADD
    this.trimStart = 0.0,               // ✅ NEW
    this.trimEnd = 1.0,                 // ✅ NEW
    this.aspectRatio = '9:16',          // ✅ NEW

  });

  @override
  State<PostActivity> createState() => _PostActivityState();
}

class _PostActivityState extends State<PostActivity> {

// ✅ මෙහෙම කරන්න (dynamic - isVideo අනුව වෙනස් වෙනවා)
  int get MAX_CHAR_LIMIT => _isVideo ? 120 : 500;
  int get MAX_TITLE_LIMIT => 100; // title limit same
  static const String BACKEND_URL = "http://10.0.2.2:5000";
//https://avishka-tiktok-api.zeabur.app
  static const String CLOUDINARY_CLOUD_NAME = "do5mpjsoh";
  static const String CLOUDINARY_API_KEY = "839992151162559";
  static const String CLOUDINARY_API_SECRET = "dcM_QHiH_zL5l4h_GBF3PdkLxrM";

  // Controllers
  final TextEditingController _descriptionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  VideoPlayerController? _videoController;
  Timer? _hashtagSearchTimer;

  // ✅ Tagged friends - store complete data for display
  final List<Map<String, String>> taggedFriends = [];

  /// දැනටමත් mention කරලා තිබෙනවා කියලා check කරන්න
  bool _isUserAlreadyMentioned(String userId) {
    return mentionedUsers.any((user) => user['uid'] == userId);
  }

  // ✅ Helper to get only UIDs for backend
  List<String> get taggedFriendUIDs =>
      taggedFriends
          .map((friend) => friend['uid'] ?? '')
          .where((uid) => uid.isNotEmpty)
          .toList();

  /// Text එකෙන් mention pattern එක validate කරන්න
  bool _isValidMentionPattern(String text) {
    return RegExp(r'@\w+').hasMatch(text);
  }

  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  FirebaseFirestore? _hashtagsDb;

  // User info
  String? currentUserId;
  String? currentUsername;
  String? currentUserEmail;
// Mutable media lists (widget params copy කරනවා)
  List<String> _localMediaPaths = [];
  List<bool> _localMediaIsVideo = [];
// Audio selection variables
  String? selectedAudioId;
  String? selectedAudioName;
  String? selectedAlbumArt;
  String? selectedSoundUrl;



// Title
  final TextEditingController _titleController = TextEditingController();
  int _titleCharCount = 0;
// ✅ Uploaded media URLs store කරන්න
  List<String> _uploadedMediaUrls = [];
  // State variables
  int _characterCount = 0;
  bool _isUploading = false;
  String selectedPrivacy = "public";
  bool isDuetAllowed = true;
  bool isSaveAllowed = true;
  bool isCommentAllowed = true;
  bool isSaveToDevice = false;

// 👇 මේ line add කරන්න
  String? selectedCategory; // null = "Select category"
  // Compression state
  bool _isCompressing = false;
  String _compressionStatus = "";

  // Media
  File? _mediaFile;
  bool _isVideo = false;
  String? _videoDuration;
  bool _isVideoPlaying = false;
  String? _videoInfo;

  // Hashtags and friends
  final List<String> selectedHashtags = [];
  final List<String> mentionedFriends = [];
  final Set<String> userHashtags = {};
  final List<String> popularHashtags = [];
  final List<String> searchResults = [];
  String lastSearchQuery = "";
  bool isSearching = false;
  bool _showHashtagSuggestions = false;

// 🆕 Mention System - State Variables
  final List<Map<String, String>> mentionedUsers = [];
  bool _showMentionSuggestions = false;
  String _lastMentionQuery = "";
  final List<Map<String, dynamic>> _mentionSearchResults = [];
  bool _isMentionSearching = false;

  // Upload progress
  int _uploadProgress = 0;
  String _uploadStatus = "";
  bool _showUploadDialog = false;
  String _uploadedFileSize = "0 B";
  String _totalFileSize = "0 B";

  // Hardcoded hashtag suggestions (matching Java exactly)
  final List<String> hashtagSuggestions = [
    // Viral & Trending
    "#Viral",
    "#Trending",
    "#ViralVideo",
    "#TrendingNow",
    "#Explore",
    "#FYP",
    "#ForYou",
    "#ForYouPage",
    "#Reels",
    "#TikTok",
    "#YouTube",
    "#Instagram",
    // Numbers & Milestones
    "#100K",
    "#1M",
    "#10M",
    "#1Million",
    "#Viral100K",
    "#MillionViews",
    "#100KViews",
    "#500K",
    "#2Million",
    "#5Million",
    // Content Categories
    "#Amazing",
    "#Incredible",
    "#Unbelievable",
    "#MindBlowing",
    "#Epic",
    "#Awesome",
    "#Beautiful",
    "#Stunning",
    "#Gorgeous",
    "#Perfect",
    "#Flawless",
    "#Breathtaking",
    // Entertainment & Fun
    "#Entertainment",
    "#Fun",
    "#Funny",
    "#Comedy",
    "#Hilarious",
    "#LOL",
    "#Entertaining",
    "#Amusing",
    "#Playful",
    "#Joyful",
    "#Happy",
    "#Smile",
    // Creative Content
    "#Creative",
    "#Art",
    "#Artist",
    "#Design",
    "#Photography",
    "#Artistic",
    "#Masterpiece",
    "#Skills",
    "#Talent",
    "#Crafts",
    "#DIY",
    // Music & Dance
    "#Music",
    "#Dance",
    "#Dancing",
    "#Song",
    "#Beat",
    "#Rhythm",
    "#Choreography",
    "#Performance",
    "#Singer",
    "#Musician",
    "#DJ",
    "#Concert",
    // Gaming
    "#Gaming",
    "#Gamer",
    "#Game",
    "#Gameplay",
    "#Stream",
    "#Streaming",
    "#Esports",
    "#Mobile",
    "#PC",
    "#Console",
    "#Pro",
    "#Skill",
    // Lifestyle
    "#Lifestyle",
    "#Daily",
    "#Routine",
    "#Vlog",
    "#Life",
    "#Living",
    "#Style",
    "#Fashion",
    "#Outfit",
    "#OOTD",
    "#Look",
    "#Trend",
    // Food & Cooking
    "#Food",
    "#Cooking",
    "#Recipe",
    "#Delicious",
    "#Tasty",
    "#Yummy",
    "#Chef",
    "#Kitchen",
    "#Foodie",
    "#Hungry",
    "#Eat",
    "#Meal",
    // Sports & Fitness
    "#Sports",
    "#Fitness",
    "#Workout",
    "#Gym",
    "#Healthy",
    "#Strong",
    "#Training",
    "#Exercise",
    "#Athlete",
    "#Football",
    "#Basketball",
    "#Cricket",
    // Technology & AI
    "#Tech",
    "#Technology",
    "#AI",
    "#Robot",
    "#Future",
    "#Innovation",
    "#Digital",
    "#Smart",
    "#Gadget",
    "#Phone",
    "#Computer",
    "#App",
    // Nature & Travel
    "#Nature",
    "#Travel",
    "#Adventure",
    "#Explore",
    "#Journey",
    "#Destination",
    "#Scenic",
    "#Wildlife",
    "#Ocean",
    "#Mountain",
    "#Sunset",
    // Motivational
    "#Motivation",
    "#Inspiration",
    "#Success",
    "#Dream",
    "#Goal",
    "#Achieve",
    "#Believe",
    "#Positive",
    "#Energy",
    "#Power",
    "#Mindset",
    // Seasonal & Events
    "#Summer",
    "#Winter",
    "#Spring",
    "#Autumn",
    "#Holiday",
    "#Festival",
    "#Celebration",
    "#Party",
    "#Event",
    "#Special",
    "#Moment",
    "#Memory",
    // Popular Culture
    "#Celebrity",
    "#Star",
    "#Famous",
    "#Popular",
    "#Icon",
    "#Legend",
    "#Movie",
    "#Film",
    "#TV",
    "#Show",
    "#Actor",
    "#Actress",
    // Social & Community
    "#Community",
    "#Together",
    "#Friends",
    "#Family",
    "#Love",
    "#Support",
    "#Share",
    "#Follow",
    "#Like",
    "#Subscribe",
    "#Comment",
    "#Engage"
  ];

  final Map<String, String> hashtagCounts = {
    // Viral & Trending
    "#Viral": "15.2B views",
    "#Trending": "8.9B views",
    "#ViralVideo": "12.4B views",
    "#TrendingNow": "6.7B views",
    "#Explore": "18.3B views",
    "#FYP": "22.1B views",
    "#ForYou": "25.8B views",
    "#ForYouPage": "19.6B views",
    "#Reels": "14.7B views",
    "#TikTok": "16.2B views",
    "#YouTube": "21.4B views",
    "#Instagram": "28.9B views",
    // Numbers & Milestones
    "#100K": "3.2B views",
    "#1M": "5.8B views",
    "#10M": "2.1B views",
    "#1Million": "4.6B views",
    "#Viral100K": "1.9B views",
    "#MillionViews": "3.7B views",
    "#100KViews": "2.8B views",
    "#500K": "1.4B views",
    "#2Million": "6.3B views",
    "#5Million": "8.1B views",
    // Content Categories
    "#Amazing": "9.4B views",
    "#Incredible": "7.2B views",
    "#Unbelievable": "5.6B views",
    "#MindBlowing": "4.1B views",
    "#Epic": "8.7B views",
    "#Awesome": "6.9B views",
    "#Beautiful": "11.3B views",
    "#Stunning": "9.8B views",
    "#Gorgeous": "7.5B views",
    "#Perfect": "5.2B views",
    "#Flawless": "4.8B views",
    "#Breathtaking": "6.1B views",
    // Entertainment & Fun
    "#Entertainment": "13.7B views",
    "#Fun": "16.2B views",
    "#Funny": "12.8B views",
    "#Comedy": "14.5B views",
    "#Hilarious": "10.9B views",
    "#LOL": "8.3B views",
    "#Entertaining": "7.6B views",
    "#Amusing": "5.4B views",
    "#Playful": "9.1B views",
    "#Joyful": "11.7B views",
    "#Happy": "15.3B views",
    "#Smile": "13.2B views",
    // Add more as needed...
  };

  void _removeTaggedFriend(String uid) {
    setState(() {
      taggedFriends.removeWhere((f) => f['uid'] == uid);
    });
    _showSnackBar('Friend removed', isSuccess: true);
  }

  @override
  void initState() {
    super.initState();
    _isVideo = widget.isVideo;       // ✅ ADD - delay එකට කලින්ම set කරන්න
    _mediaFile = widget.mediaFile; // ✅ ADD - preview වලට
    if (_isVideo) {
      _initializeVideoPlayer(); // ✅ ADD - delay බලන්නේ නෑ, ගොඩ කලින් start කරනවා
    }
    _initializeActivity();
  }

  Future<void> _initializeActivity() async {
    _descriptionController.addListener(_onDescriptionChanged);
    _titleController.addListener(() {          // ✅ ADD
      setState(() {                            // ✅ ADD
        _titleCharCount = _titleController.text.length; // ✅ ADD
      });                                      // ✅ ADD
    });
    await _getCurrentUserInfo();
    _handleSelectedMedia();
    await Future.delayed(const Duration(seconds: 1));
    await _initializeHashtagSystem();
// 🆕 Extract audio metadata
    await _extractAudioMetadata();
  }

  void _onDescriptionChanged() {
    setState(() {
      _characterCount = _descriptionController.text.length;
    });
    _checkForHashtagSearch(_descriptionController.text);
    _checkForMentionSearch(
        _descriptionController.text); // 🆕 මේ line එක add කරන්න
  }

  Future<void> _getCurrentUserInfo() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      currentUserId = currentUser.uid;
      currentUserEmail = currentUser.email;

      debugPrint('🔐 Current User UID: $currentUserId');
      debugPrint('📧 Current User Email: $currentUserEmail');

      try {
        final userDoc = await _db.collection('users').doc(currentUserId).get();
        if (userDoc.exists) {
          currentUsername = userDoc.data()?['name'] as String?;
          debugPrint('👤 Current Username: $currentUsername');
        } else {
          debugPrint('⚠️ User document not found in Firestore');
          currentUsername = currentUser.displayName;
        }
      } catch (e) {
        debugPrint('❌ Error getting user document: $e');
        currentUsername = currentUser.displayName;
      }
    } else {
      debugPrint('❌ No authenticated user found');
      // Navigate to login
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  Future<void> _initializeHashtagSystem() async {
    _hashtagsDb = FirebaseFirestore.instance;
    await _loadUserHashtagsWithFallback();
    await _loadPopularHashtagsWithFallback();
  }

  Future<void> _loadUserHashtagsWithFallback() async {
    if (currentUserId == null) {
      debugPrint('No current user, using fallback hashtags');
      _loadFallbackHashtags();
      return;
    }

    try {
      final doc = await _hashtagsDb!
          .collection('user_hashtags')
          .doc(currentUserId)
          .get();

      if (doc.exists) {
        final hashtags = doc.data()?['hashtags'] as List<dynamic>?;
        if (hashtags != null) {
          userHashtags.clear();
          userHashtags.addAll(hashtags.cast<String>());
          debugPrint('✅ Loaded ${userHashtags.length} user hashtags');
        }
      } else {
        debugPrint('📝 No user hashtags found, creating empty collection');
        await _createEmptyUserHashtagsCollection();
      }
      _updateHashtagSuggestions();
    } catch (e) {
      debugPrint('❌ Failed to load user hashtags, using fallback: $e');
      _loadFallbackHashtags();
      _updateHashtagSuggestions();
    }
  }

  Future<void> _loadPopularHashtagsWithFallback() async {
    try {
      final querySnapshot = await _hashtagsDb!
          .collection('popular_hashtags')
          .orderBy('usage_count', descending: true)
          .limit(20)
          .get();

      popularHashtags.clear();
      for (var doc in querySnapshot.docs) {
        final hashtag = doc.data()['hashtag'] as String?;
        if (hashtag != null) {
          popularHashtags.add(hashtag);
        }
      }

      debugPrint('✅ Loaded ${popularHashtags.length} popular hashtags');

      if (popularHashtags.isEmpty) {
        _loadFallbackHashtags();
      }
      _updateHashtagSuggestions();
    } catch (e) {
      debugPrint('❌ Failed to load popular hashtags, using fallback: $e');
      _loadFallbackHashtags();
      _updateHashtagSuggestions();
    }
  }

  void _loadFallbackHashtags() {
    final fallbackHashtags = [
      "#Viral",
      "#Trending",
      "#ViralVideo",
      "#Amazing",
      "#ForYou",
      "#100k",
      "#Beautiful",
      "#Creative",
      "#Dance",
      "#Entertainment",
      "#Fun",
      "#Gaming",
      "#Love",
      "#Happy",
      "#Life",
      "#Music",
      "#Art",
      "#Fashion",
      "#Food",
      "#Travel"
    ];

    popularHashtags.clear();
    popularHashtags.addAll(fallbackHashtags);
    debugPrint('📱 Using fallback hashtags: ${popularHashtags.length} items');
  }

  Future<void> _createEmptyUserHashtagsCollection() async {
    try {
      await _hashtagsDb!.collection('user_hashtags').doc(currentUserId).set({
        'hashtags': [],
        'created_at': FieldValue.serverTimestamp(),
        'last_updated': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Created empty user hashtags collection');
    } catch (e) {
      debugPrint('❌ Failed to create user hashtags collection: $e');
    }
  }
  /// Get sound/audio metadata from selected media
  Future<void> _extractAudioMetadata() async {

      try {
        if (_isVideo) {
          if (widget.selectedMusicPath != null &&
              widget.selectedMusicId != null) {
            setState(() {
              selectedAudioId = widget.selectedMusicId;
              selectedAudioName = _cleanAudioName(widget.selectedMusicName);
              selectedAlbumArt = widget.selectedMusicAlbumArt;
              selectedSoundUrl = widget.selectedMusicPath;
            });
            debugPrint('🎵 Video - Custom music: $selectedAudioName');
          } else {
            setState(() {
              selectedAudioId = 'original_$currentUserId';
              selectedAudioName = 'Original Sound';
              selectedAlbumArt = null;
              selectedSoundUrl = null;
            });
            debugPrint('🎵 Video - Original Sound');
          }
        } else {
          // Image post
          if (widget.selectedMusicPath != null &&
              widget.selectedMusicPath!.isNotEmpty) {
            setState(() {
              selectedAudioId = widget.selectedMusicId ?? 'sound_${DateTime
                  .now()
                  .millisecondsSinceEpoch}';
              selectedAudioName = _cleanAudioName(widget.selectedMusicName);
              selectedAlbumArt = null;
              selectedSoundUrl = widget.selectedMusicPath; // ✅ actual URL/path
            });
            debugPrint('🎵 Image sound: $selectedAudioName → $selectedSoundUrl');
          } else {
            selectedAudioId = selectedAudioName = selectedAlbumArt =
                selectedSoundUrl = null;
            debugPrint('🎵 Image - No sound');
          }
        }
      } catch (e) {
        debugPrint('❌ Error extracting audio metadata: $e');
      }
    }
  /// audio_name hash value නම් clean කරනවා
  String _cleanAudioName(String? rawName) {
    if (rawName == null || rawName.isEmpty) return 'Custom Sound';

    // MD5 hash pattern check (32 hex characters)
    final hashPattern = RegExp(r'^[a-f0-9]{32}$', caseSensitive: false);
    if (hashPattern.hasMatch(rawName.trim())) {
      debugPrint('⚠️ audio_name is a hash, replacing with "Custom Sound"');
      return 'Custom Sound';
    }

    // File path නම් filename ගන්නවා (extension remove කරලා)
    if (rawName.contains('/') || rawName.contains(r'\')) {
      final fileName = rawName.split(RegExp(r'[/\\]')).last;
      final nameWithoutExt = fileName.replaceAll(
          RegExp(r'\.(mp3|aac|wav|m4a|ogg|flac)$', caseSensitive: false), '');
      final cleaned = nameWithoutExt.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
      return cleaned.isNotEmpty ? cleaned : 'Custom Sound';
    }

    return rawName.trim();
  }
  void _updateHashtagSuggestions() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleSelectedMedia() {
    // ✅ FIX: Always initialize local media lists first
    _localMediaPaths = List.from(
        widget.allMediaPaths.isNotEmpty ? widget.allMediaPaths : [widget.mediaFile.path]
    );
    _localMediaIsVideo = List.from(
        widget.allMediaIsVideo.isNotEmpty ? widget.allMediaIsVideo : [widget.isVideo]
    );
    if (widget.mediaFile.path.isNotEmpty) {
      _mediaFile = widget.mediaFile;
      _isVideo = widget.isVideo;

      debugPrint('✅ Media loaded from direct parameters');
      debugPrint('   File path: ${_mediaFile!.path}');
      debugPrint('   Is video: $_isVideo');

      if (_isVideo) {
        _initializeVideoPlayer();
      }

      _calculateFileSize();
      setState(() {});
      return;
    }

    if (widget.selectedMedia != null && widget.selectedMedia!.isNotEmpty) {
      final mediaPath = widget.selectedMedia![0];
      _mediaFile = File(mediaPath);
      _isVideo = widget.mediaType == 'video';

      debugPrint('✅ Media loaded from selectedMedia list');
      debugPrint('   File path: $mediaPath');
      debugPrint('   Is video: $_isVideo');

      if (_isVideo) {
        _initializeVideoPlayer();
      }
// Local mutable copies initialize කරන්න
      _localMediaPaths = List.from(
          widget.allMediaPaths.isNotEmpty
              ? widget.allMediaPaths
              : [widget.mediaFile.path]
      );
      _localMediaIsVideo = List.from(
          widget.allMediaIsVideo.isNotEmpty
              ? widget.allMediaIsVideo
              : [widget.isVideo]
      );
      _calculateFileSize();
      setState(() {});
      return;
    }

    debugPrint('❌ No media found!');
  }

  void _calculateFileSize() {
    if (_mediaFile != null) {
      final bytes = _mediaFile!.lengthSync();
      _totalFileSize = _formatFileSize(bytes);
      debugPrint('📁 File size: $bytes bytes ($_totalFileSize)');
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";

    const units = ["B", "KB", "MB", "GB"];
    int digitGroups = (math.log(bytes) / math.log(1024)).floor();

    return '${(bytes / math.pow(1024, digitGroups)).toStringAsFixed(
        1)} ${units[digitGroups]}';
  }

  Future<File?> _compressImage(File imageFile) async {
    try {
      debugPrint('🖼️ Starting image compression...');

      final targetPath = '${imageFile.parent.path}/compressed_${DateTime
          .now()
          .millisecondsSinceEpoch}.jpg';

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 80, // ✅ 85 → 80 (more compression)
        minWidth: 1080,
        minHeight: 1920,
        format: CompressFormat.jpeg,
      );

      if (compressedFile != null) {
        final originalSize = imageFile.lengthSync();
        final compressedSize = io.File(compressedFile.path).lengthSync();

        debugPrint('✅ Image compressed successfully!');
        debugPrint('   Original: ${_formatFileSize(originalSize)}');
        debugPrint('   Compressed: ${_formatFileSize(compressedSize)}');
        debugPrint(
            '   Saved: ${_formatFileSize(originalSize - compressedSize)}');

        return io.File(compressedFile.path);
      }

      debugPrint('⚠️ Compression returned null, using original');
      return imageFile;
    } catch (e) {
      debugPrint('❌ Image compression error: $e');
      return imageFile;
    }
  }

  Future<File?> _compressVideo(File videoFile) async {
    try {
      final int originalSize = videoFile.lengthSync();

      // 💡 1. දැනටමත් 2MB ට වඩා අඩු නම්, කම්ප්‍රෙස් කරලා කාලය නාස්ති කරන්න එපා.
      if (originalSize < 2 * 1024 * 1024) {
        debugPrint('⏩ Skipping compression: File is already small enough.');
        return videoFile;
      }

      debugPrint('🎬 Starting video compression...');

      final mediaInfo = await VideoCompress.compressVideo(
        videoFile.path,
        // 💡 2. මෙතනට MediumQuality දාන්න. එතකොට 50MB එක 10MB-15MB වගේ වෙයි.
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (mediaInfo != null && mediaInfo.file != null) {
        final compressedSize = mediaInfo.filesize ?? 0;

        // 💡 3. වැදගත්ම දේ: කම්ප්‍රෙස් කරපු එක ඔරිජිනල් එකට වඩා වැඩි නම්, ඔරිජිනල් එකම යවන්න.
        if (compressedSize >= originalSize) {
          debugPrint(
              '⚠️ Compression made it larger! Using original file instead.');
          return videoFile;
        }

        debugPrint(
            '✅ Success: ${_formatFileSize(originalSize)} -> ${_formatFileSize(
                compressedSize)}');
        return mediaInfo.file;
      }

      return videoFile;
    } catch (e) {
      debugPrint('❌ Error during compression: $e');
      return videoFile;
    }
  }

  void _initializeVideoPlayer() {
    if (_mediaFile != null) {
      _videoController = VideoPlayerController.file(_mediaFile!)
        ..initialize().then((_) {
          setState(() {
            final duration = _videoController!.value.duration;
            _videoDuration = _formatDuration(duration);

            // Get video info
            final size = _videoController!.value.size;
            _videoInfo = '${size.width.toInt()}x${size.height.toInt()}';
          });
        }).catchError((error) {
          debugPrint('❌ Video initialization error: $error');
        });

      _videoController!.addListener(() {
        if (_videoController!.value.isPlaying != _isVideoPlaying) {
          setState(() {
            _isVideoPlaying = _videoController!.value.isPlaying;
          });
        }
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  void _checkForHashtagSearch(String text) {
    // ✅ FIXED: Safety check for cursor position
    final selection = _descriptionController.selection;
    if (!selection.isValid || selection.baseOffset < 0) {
      if (_showHashtagSuggestions) {
        setState(() {
          _showHashtagSuggestions = false;
        });
      }
      return;
    }

    final cursorPosition = selection.baseOffset;

    // ✅ Safety check: text එක empty නම් හෝ cursor invalid නම්
    if (text.isEmpty || cursorPosition <= 0) {
      if (_showHashtagSuggestions) {
        setState(() {
          _showHashtagSuggestions = false;
        });
      }
      return;
    }

    // ✅ Safe lastIndexOf with bounds check
    final searchStart = cursorPosition - 1;
    if (searchStart < 0 || searchStart >= text.length) {
      if (_showHashtagSuggestions) {
        setState(() {
          _showHashtagSuggestions = false;
        });
      }
      return;
    }

    final hashPosition = text.lastIndexOf('#', searchStart);

    if (hashPosition != -1) {
      final validHashtagStart = hashPosition == 0 ||
          text[hashPosition - 1] == ' ';

      if (validHashtagStart) {
        String hashtagPart = '';
        int endPosition = cursorPosition;

        for (int i = hashPosition; i < text.length &&
            i <= cursorPosition; i++) {
          if (text[i] == ' ') break;
          if (i == cursorPosition) {
            endPosition = i;
            break;
          }
        }

        if (endPosition > hashPosition) {
          hashtagPart = text.substring(hashPosition + 1, endPosition);

          // ✅ FIX: Ignore if hashtag contains @ or other invalid chars
          if (hashtagPart.isNotEmpty && !hashtagPart.contains('@')) {
            _performHashtagSearch(hashtagPart);
            return;
          }
        }
      }
    }

    if (_showHashtagSuggestions) {
      setState(() {
        _showHashtagSuggestions = false;
      });
    }
  }

  void _performHashtagSearch(String query) {
    if (query == lastSearchQuery && searchResults.isNotEmpty) {
      if (!_showHashtagSuggestions) {
        setState(() {
          _showHashtagSuggestions = true;
        });
      }
      return;
    }

    lastSearchQuery = query;

    _hashtagSearchTimer?.cancel();
    _hashtagSearchTimer = Timer(const Duration(milliseconds: 300), () {
      _searchHashtags(query);
    });
  }

  Future<void> _searchHashtags(String query) async {
    if (isSearching) return;

    setState(() {
      isSearching = true;
      searchResults.clear();
    });

    final searchQuery = query.toLowerCase();
    debugPrint('🔍 Searching hashtags for: $searchQuery');

    // Search user hashtags
    for (var hashtag in userHashtags) {
      if (hashtag.toLowerCase().contains(searchQuery)) {
        searchResults.add(hashtag);
      }
    }
    debugPrint('📝 Found ${searchResults.length} user hashtags');

    // Search popular hashtags
    for (var hashtag in popularHashtags) {
      if (hashtag.toLowerCase().contains(searchQuery) &&
          !searchResults.contains(hashtag)) {
        searchResults.add(hashtag);
      }
    }

    // Search hardcoded suggestions
    for (var hashtag in hashtagSuggestions) {
      if (hashtag.toLowerCase().contains(searchQuery) &&
          !searchResults.contains(hashtag)) {
        searchResults.add(hashtag);
      }
    }
    debugPrint('🌟 Total results after popular search: ${searchResults.length}');

    // Search Firestore
    await _searchFirestoreHashtags(searchQuery);

    setState(() {
      isSearching = false;
      _showHashtagSuggestions = true;
    });

    debugPrint('🔥 Final results count: ${searchResults.length}');
  }

  Future<void> _searchFirestoreHashtags(String query) async {
    if (_hashtagsDb == null) return;

    try {
      final querySnapshot = await _hashtagsDb!
          .collection('popular_hashtags')
          .where('hashtag', isGreaterThanOrEqualTo: '#$query')
          .where('hashtag', isLessThanOrEqualTo: '#$query\uf8ff')
          .limit(10)
          .get();

      for (var doc in querySnapshot.docs) {
        final hashtag = doc.data()['hashtag'] as String?;
        if (hashtag != null && !searchResults.contains(hashtag)) {
          searchResults.add(hashtag);
        }
      }
    } catch (e) {
      debugPrint('❌ Firestore search failed: $e');
    }
  }

  Future<void> _saveHashtagToFirestore(String hashtag) async {
    if (currentUserId == null || hashtag
        .trim()
        .isEmpty) {
      debugPrint('Cannot save hashtag - missing user ID or hashtag');
      return;
    }

    final cleanHashtag = hashtag.startsWith('#') ? hashtag : '#$hashtag';

    // Save to user collection
    await _saveToUserHashtagsCollection(cleanHashtag);

    // Save to global collection
    await _saveToGlobalHashtagsCollection(cleanHashtag);
  }

  Future<void> _saveToUserHashtagsCollection(String hashtag) async {
    userHashtags.add(hashtag);

    try {
      await _hashtagsDb!.collection('user_hashtags').doc(currentUserId).set({
        'hashtags': userHashtags.toList(),
        'last_updated': FieldValue.serverTimestamp(),
        'total_count': userHashtags.length,
      }, SetOptions(merge: true));

      debugPrint('✅ Saved hashtag to user collection: $hashtag');
    } catch (e) {
      debugPrint('❌ Failed to save user hashtag: $hashtag - $e');
    }
  }

  Future<void> _saveToGlobalHashtagsCollection(String hashtag) async {
    final docId = hashtag
        .toLowerCase()
        .replaceAll('#', '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

    if (docId.isEmpty) {
      debugPrint('Invalid hashtag for global collection: $hashtag');
      return;
    }

    try {
      final hashtagRef = _hashtagsDb!.collection('popular_hashtags').doc(docId);
      final doc = await hashtagRef.get();

      if (doc.exists) {
        await hashtagRef.update({
          'usage_count': FieldValue.increment(1),
          'last_used': FieldValue.serverTimestamp(),
          'users_used': FieldValue.arrayUnion([currentUserId]),
        });
        debugPrint('✅ Updated global hashtag: $hashtag');
      } else {
        await hashtagRef.set({
          'hashtag': hashtag,
          'usage_count': 1,
          'created_at': FieldValue.serverTimestamp(),
          'last_used': FieldValue.serverTimestamp(),
          'users_used': [currentUserId],
          'category': 'user_generated',
        });
        debugPrint('✅ Created new global hashtag: $hashtag');
      }
    } catch (e) {
      debugPrint('❌ Failed to save global hashtag: $hashtag - $e');
    }
  }

  void _insertHashtagAtCursor(String hashtag) {
    final currentText = _descriptionController.text;
    final cursorPosition = _descriptionController.selection.baseOffset;
    final hashPosition = currentText.lastIndexOf('#', cursorPosition - 1);

    if (hashPosition != -1) {
      final beforeHash = currentText.substring(0, hashPosition);
      final afterCursor = currentText.substring(cursorPosition);
      final newText = '$beforeHash$hashtag $afterCursor';

      _descriptionController.text = newText;
      _descriptionController.selection = TextSelection.fromPosition(
        TextPosition(offset: hashPosition + hashtag.length + 1),
      );
    } else {
      _addHashtagToDescription(hashtag);
    }
  }

  void _addHashtagToDescription(String hashtag) {
    String currentText = _descriptionController.text;

    if (currentText.endsWith('#')) {
      currentText = currentText.substring(0, currentText.length - 1);
    }

    if (currentText.isNotEmpty && !currentText.endsWith(' ')) {
      currentText += ' ';
    }

    currentText += '$hashtag ';
    _descriptionController.text = currentText;
    _descriptionController.selection = TextSelection.fromPosition(
      TextPosition(offset: currentText.length),
    );
  }

  Future<bool> _isNetworkAvailable() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _handlePostButtonClick() async {
    // 1️⃣ Title validation (image only)
    if (!_isVideo) {
      final title = _titleController.text.trim();
      if (title.length > MAX_TITLE_LIMIT) {
        _showSnackBar('Title is too long. Maximum $MAX_TITLE_LIMIT characters allowed.');
        return;
      }
    }
    // Check network
    if (!await _isNetworkAvailable()) {
      _showErrorDialog(
        'No internet connection detected. Please check your network settings.',
      );
      return;
    }

    // 2️⃣ Description validation
    final description = _descriptionController.text.trim();
    if (description.length > MAX_CHAR_LIMIT) {
      _showSnackBar('Description is too long. Maximum $MAX_CHAR_LIMIT characters allowed.');
      return;
    }
    // 3️⃣ Media check
    if (_localMediaPaths.isEmpty && _mediaFile == null) {
      _showSnackBar('Please select at least one image or video.');
      return;
    }

    if (description.length > MAX_CHAR_LIMIT) {
      _showSnackBar('Description exceeds character limit');
      return;
    }

    if (_mediaFile == null) {
      _showSnackBar('No media selected');
      return;
    }

    // Show upload dialog
    setState(() {
      _showUploadDialog = true;
      _uploadProgress = 5;
      _uploadStatus = 'Checking connection...';
    });

    await Future.delayed(const Duration(milliseconds: 100));

    File processedFile = _mediaFile!;

    try {
      // 🎬 STEP 1: VIDEO TRIM
      if (_isVideo) {
        setState(() {
          _uploadProgress = 10;
          _uploadStatus = 'Checking video duration...';
        });

        final trimmedFile = await _checkAndTrimVideo(processedFile);

        if (trimmedFile == null) {
          setState(() {
            _showUploadDialog = false;
          });

          _showErrorDialog(
            'Failed to process video. Videos longer than 30 seconds must be trimmed.\n\n'
                'Please try again or use a shorter video.',
          );
          return;
        }

        processedFile = trimmedFile;
      }
// ✅ STEP 1.5: RENDER FINAL MEDIA (edits bake කරනවා)
      setState(() {
        _uploadProgress = 8;
        _uploadStatus = 'Applying edits...';
      });
      processedFile = await _renderFinalMedia(processedFile);
      debugPrint('✅ Render complete: ${processedFile.path}');
      // ✅ STEP 2: COMPRESSION
      setState(() {
        _isCompressing = true;
        _uploadProgress = 15;
        _uploadStatus = 'Compressing media...';
        _compressionStatus = 'Preparing compression...';
      });

      File? compressedFile;

      if (_isVideo) {
        setState(() {
          _compressionStatus = 'Compressing video... This may take a moment';
        });
        compressedFile = await _compressVideo(processedFile);
      } else {
        setState(() {
          _compressionStatus = 'Compressing image...';
        });
        compressedFile = await _compressImage(processedFile);
      }

      setState(() {
        _isCompressing = false;
        _uploadProgress = 20;
        _uploadStatus = 'Compression complete! Starting upload...';
      });

      await Future.delayed(const Duration(milliseconds: 500));

      // 🚀 STEP 3: CLOUDINARY UPLOAD
      final finalFile = compressedFile ?? processedFile;

      // ✅ Multiple images නම් parallel upload
      if (!_isVideo && _localMediaPaths.length > 1) {
        setState(() {
          _uploadProgress = 30;
          _uploadStatus = 'Uploading ${_localMediaPaths.length} images...';
        });

        final List<File> filesToUpload = [];
        for (String path in _localMediaPaths) {
          final file = File(path);
          final compressed = await _compressImage(file);
          filesToUpload.add(compressed ?? file);
        }

        _uploadedMediaUrls = await _uploadMultipleImagesToCloudinary(filesToUpload);

          // Primary URL = 1වෙනි image URL
        final primaryUrl = _uploadedMediaUrls[0];
        final primaryPublicId = primaryUrl.split('/').last.split('.').first;
        setState(() {
          _uploadProgress = 90;
          _uploadStatus = 'Saving post...';
        });

        await _sendPostToBackend(
          primaryUrl,
          primaryPublicId,
          description,
          'image',
        );
        return;
      }

      // Single image / video
      await _uploadMediaToCloudinary(finalFile, description);

    } catch (e) {
      debugPrint('❌ Processing failed: $e');
      setState(() {
        _isCompressing = false;
        _showUploadDialog = false;
      });
      _showErrorDialog('Processing failed. Please try again.');
    }
  }
// ════════════════════════════════════════════════════════
// FINAL RENDER — Post button hit වෙද්දී ඔක්කොම bake කරනවා
// ════════════════════════════════════════════════════════
  Future<File> _renderFinalMedia(File original) async {
    if (_isVideo) {
      return await _renderFinalVideo(original) ?? original;
    } else {
      return await _renderFinalImage(original);
    }
  }

// ── IMAGE RENDER (dart:ui canvas) ───────────────────────────────
  Future<File> _renderFinalImage(File originalFile) async {
    setState(() {
      _uploadProgress = 10;
      _uploadStatus = 'Rendering image edits...';
    });


    final imageBytes = await originalFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final srcImage = frame.image;

    final imgW = srcImage.width.toDouble();
    final imgH = srcImage.height.toDouble();
    double cropW = imgW;
    double cropH = imgH;
    double cropX = 0;
    double cropY = 0;
    switch (widget.aspectRatio) {
      case '1:1':
        if (imgW > imgH) {
          cropW = imgH;
          cropX = (imgW - imgH) / 2;
        } else {
          cropH = imgW;
          cropY = (imgH - imgW) / 2;
        }
        break;
      case '16:9':
        final targetH = imgW * 9 / 16;
        if (targetH <= imgH) {
          cropH = targetH;
          cropY = (imgH - targetH) / 2;
        }
        break;
      case '4:5':
        final targetH = imgW * 5 / 4;
        if (targetH <= imgH) {
          cropH = targetH;
          cropY = (imgH - targetH) / 2;
        }
        break;
      case '3:4':
        final targetH = imgW * 4 / 3;
        if (targetH <= imgH) {
          cropH = targetH;
          cropY = (imgH - targetH) / 2;
        }
        break;
    // 9:16 = default, no crop needed
    }
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final scaleX = imgW / screenW;
    final scaleY = imgH / screenH;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, imgW, imgH));

    // ── 1. Original image + Color Filter ──────────────────────────
    final paint = Paint();
    if (widget.activeFilterMatrix != null) {
      paint.colorFilter = ColorFilter.matrix(widget.activeFilterMatrix!);
    }
    canvas.drawImageRect(
      srcImage,
      Rect.fromLTWH(cropX, cropY, cropW, cropH),  // Source (crop region)
      Rect.fromLTWH(0, 0, cropW, cropH),           // Destination
      paint,
    );


    // ── Effects ───────────────────────────────
    for (final layer in widget.effectLayers) {
      _drawEffectOnCanvas(canvas, Size(imgW, imgH), layer.effectKey, layer.intensity);
    }
    // ── 2. Stickers ───────────────────────────────────────────────
    for (final sticker in widget.placedStickers) {
      final emoji = sticker['emoji'] as String;
      final x = (sticker['x'] as double) * scaleX;
      final y = (sticker['y'] as double) * scaleY;
      final scale = (sticker['scale'] as double);
      final angle = (sticker['angle'] as double);
      final fontSize = 52.0 * scaleX * scale;

      final tp = TextPainter(
        text: TextSpan(text: emoji, style: TextStyle(fontSize: fontSize)),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // ── 4. Text Overlays ───────────────────────────────────────────────
    for (final overlay in widget.textOverlays) {
      Color overlayColor = Colors.white;
      FontWeight weight  = FontWeight.normal;
      FontStyle  style   = FontStyle.normal;
      try {
        final dynamic d = overlay;
        Color? c;
        try { c = d.textColor as Color?; } catch (_) {}
        if (c == null) { try { c = d.color as Color?; } catch (_) {} }
        if (c != null) overlayColor = c;
        try { if (d.isBold   == true) weight = FontWeight.bold;  } catch (_) {}
        try { if (d.isItalic == true) style  = FontStyle.italic; } catch (_) {}
      } catch (_) {}

      final tp = TextPainter(
        text: TextSpan(
          text: overlay.text,
          style: TextStyle(
            fontSize:   overlay.fontSize * scaleX,
            color:      overlayColor,
            fontWeight: weight,
            fontStyle:  style,
            shadows: const [Shadow(color: Colors.black54, offset: Offset(2,2), blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: imgW);

      tp.paint(canvas, Offset(overlay.x * scaleX, overlay.y * scaleY));
    }
    // ── PNG export ─────────────────────────────────────────────────────
    final picture  = recorder.endRecording();
    final img      = await picture.toImage(imgW.toInt(), imgH.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes    = byteData!.buffer.asUint8List();

    final tempDir = await getTemporaryDirectory();
    final outPath = '${tempDir.path}/rendered_${DateTime.now().millisecondsSinceEpoch}.png';
    final outFile = File(outPath);
    await outFile.writeAsBytes(bytes);

    debugPrint('✅ Image rendered: $outPath');
    return outFile;
  }

// ── VIDEO RENDER (FFmpeg) ────────────────────────────────────────
  Future<File?> _renderFinalVideo(File videoFile) async {
    setState(() {
      _uploadProgress = 10;
      _uploadStatus = 'Rendering video edits...';
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final outPath =
          '${tempDir.path}/rendered_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // ── Video dimensions ─────────────────────────────────────────────────
      double vidW = 1080;
      double vidH = 1920;
      if (_videoController != null && _videoController!.value.isInitialized) {
        vidW = _videoController!.value.size.width;
        vidH = _videoController!.value.size.height;
      }

      final screenW = MediaQuery.of(context).size.width;
      final screenH = MediaQuery.of(context).size.height;
      final scaleX = vidW / screenW;
      final scaleY = vidH / screenH;

      // ── STEP 1: Stickers + Text → PNG overlay image (dart:ui canvas) ────
      // Stickers emoji FFmpeg drawtext support නෑ, ඒ නිසා canvas එකේ render
      final bool hasStickers = widget.placedStickers.isNotEmpty;
      final bool hasTextOverlays = widget.textOverlays.isNotEmpty;
      final bool hasEffects = widget.effectLayers.isNotEmpty; // ← ADD
      String? overlayImagePath;

      if (hasStickers || hasTextOverlays || hasEffects) {
        overlayImagePath = await _renderOverlayImage(
          vidW: vidW,
          vidH: vidH,
          scaleX: scaleX,
          scaleY: scaleY,
        );
        debugPrint('🖼️ Overlay image: $overlayImagePath');
      }

      // ── STEP 2: FFmpeg vf filter chain (color matrix) ────────────────────
      final List<String> vfFilters = [];

      if (widget.activeFilterMatrix != null) {
        final m = widget.activeFilterMatrix!;
        vfFilters.add(
          'colorchannelmixer='
              'rr=${m[0]}:rg=${m[1]}:rb=${m[2]}:'
              'gr=${m[5]}:gg=${m[6]}:gb=${m[7]}:'
              'br=${m[10]}:bg=${m[11]}:bb=${m[12]}',
        );
      }

      // ── STEP 3: Build FFmpeg command ─────────────────────────────────────
      String command;

      if (overlayImagePath != null) {
        // Overlay image තිබෙනවා (stickers/text) — overlay filter use කරනවා
        // filter_complex: [0:v] color filter → [colored]; [colored][1:v] overlay → [v]
        final colorPart = vfFilters.isNotEmpty
            ? '[0:v]${vfFilters.join(',')}[colored];[colored][1:v]overlay=0:0[v]'
            : '[0:v][1:v]overlay=0:0[v]';

        if (widget.selectedMusicPath == null) {
          final afPart = widget.originalAudioVolume < 1.0
              ? '[0:a]volume=${widget.originalAudioVolume}[a]'
              : '[0:a]acopy[a]';

          command =
          '-i "${videoFile.path}" -i "$overlayImagePath" '
              '-filter_complex '
              '"$colorPart;$afPart" '
              '-map "[v]" -map "[a]" '
              '-c:v libx264 -preset fast -crf 23 -c:a aac "${outPath}"';
        } else {
          // Music + overlay
          final colorAndOverlay = colorPart; // already built above

          command =
          '-i "${videoFile.path}" -i "$overlayImagePath" -i "${widget.selectedMusicPath}" '
              '-filter_complex '
              '"$colorAndOverlay;'
              '[0:a]volume=${widget.originalAudioVolume}[a0];'
              '[2:a]volume=${widget.musicVolume}[a1];'
              '[a0][a1]amix=inputs=2:duration=first[a]" '
              '-map "[v]" -map "[a]" '
              '-c:v libx264 -preset fast -crf 23 -c:a aac -shortest "${outPath}"';
        }
      } else {
        // Overlay නෑ — simple case (filter හෝ music විතරයි)
        if (widget.selectedMusicPath == null) {
          final vfPart =
          vfFilters.isNotEmpty ? '-vf "${vfFilters.join(',')}"' : '';
          final afPart = widget.originalAudioVolume < 1.0
              ? '-af "volume=${widget.originalAudioVolume}"'
              : '';
          command = '-i "${videoFile.path}" $vfPart $afPart '
              '-c:v libx264 -preset fast -crf 23 -c:a aac "${outPath}"';
        } else {
          final vfChain =
          vfFilters.isNotEmpty ? vfFilters.join(',') : 'copy';
          command =
          '-i "${videoFile.path}" -i "${widget.selectedMusicPath}" '
              '-filter_complex '
              '"[0:v]${vfChain}[v];'
              '[0:a]volume=${widget.originalAudioVolume}[a0];'
              '[1:a]volume=${widget.musicVolume}[a1];'
              '[a0][a1]amix=inputs=2:duration=first[a]" '
              '-map "[v]" -map "[a]" '
              '-c:v libx264 -preset fast -crf 23 -c:a aac -shortest "${outPath}"';
        }
      }

      debugPrint('🎬 FFmpeg command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Temp overlay image cleanup
      if (overlayImagePath != null) {
        try { File(overlayImagePath).deleteSync(); } catch (_) {}
      }

      if (returnCode != null && returnCode.getValue() == 0) {
        debugPrint('✅ Video rendered: $outPath');
        return File(outPath);
      } else {
        final logs = await session.getAllLogsAsString();
        debugPrint('❌ FFmpeg failed: $logs');
        return videoFile;
      }
    } catch (e) {
      debugPrint('❌ Video render error: $e');
      return videoFile;
    }
  }
// ── Effect key → Canvas draw (static snapshot for PNG export) ────────────────
// animated effects → t=0.5 snapshot, particle effects → fixed positions
  void _drawEffectOnCanvas(Canvas canvas, Size size, String effectKey, double intensity) {
    const t = 0.5; // mid-animation snapshot

    switch (effectKey) {

    // ════════════════════════════════
    // ⚡ VISUAL
    // ════════════════════════════════

      case 'glitch':
      // Red/blue channel split + scan bars
        final offset = (t - 0.5) * 20 * intensity;
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..color = Colors.red.withOpacity(0.15 * intensity)..blendMode = BlendMode.srcOver);
        canvas.drawRect(Rect.fromLTWH(offset, 0, size.width, size.height),
            Paint()..color = Colors.blue.withOpacity(0.15 * intensity)..blendMode = BlendMode.srcOver);
        final rng1 = Random(42);
        for (int i = 0; i < (intensity * 4).toInt(); i++) {
          final y = rng1.nextDouble() * size.height;
          canvas.drawRect(Rect.fromLTWH(0, y, size.width, rng1.nextDouble() * 4 + 1),
              Paint()..color = Colors.white.withOpacity(0.06 * intensity));
        }
        break;

      case 'rgb':
        canvas.drawRect(Rect.fromLTWH(-6 * intensity, 0, size.width, size.height),
            Paint()..color = Colors.red.withOpacity(0.15 * intensity));
        canvas.drawRect(Rect.fromLTWH(6 * intensity, 0, size.width, size.height),
            Paint()..color = Colors.blue.withOpacity(0.15 * intensity));
        break;

      case 'mirror':
        canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height),
            Paint()..color = Colors.white.withOpacity(0.25 * intensity)..strokeWidth = 1.5);
        break;

      case 'pixelate':
      // Subtle color blocks overlay
        final rng2 = Random(42);
        const blockSize = 8.0;
        for (double x = 0; x < size.width; x += blockSize) {
          for (double y = 0; y < size.height; y += blockSize) {
            canvas.drawRect(Rect.fromLTWH(x, y, blockSize - 1, blockSize - 1),
                Paint()..color = Colors.white.withOpacity(rng2.nextDouble() * 0.05 * intensity));
          }
        }
        break;

      case 'shake':
      // Static: mild horizontal offset tint
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..color = Colors.white.withOpacity(0.04 * intensity));
        break;

      case 'zoom_pulse':
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..shader = RadialGradient(
              colors: [Colors.transparent, Colors.black.withOpacity(0.12 * intensity)],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
        break;

      case 'color_shift':
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..color = HSVColor.fromAHSV(0.10 * intensity, 180, 1.0, 1.0).toColor());
        break;

      case 'invert':
      // Partial invert via color matrix overlay
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..color = Colors.white.withOpacity(0.08 * intensity));
        break;

      case 'scanline':
        for (double y = 0; y < size.height; y += 2) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y),
              Paint()..color = Colors.black.withOpacity(0.12 * intensity)..strokeWidth = 1);
        }
        break;

      case 'edge_glow':
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..shader = LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [
                Colors.orange.withOpacity(0.25 * intensity),
                Colors.transparent,
                Colors.deepOrange.withOpacity(0.25 * intensity),
              ],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
        break;

      case 'kaleidoscope':
        final cx1 = size.width / 2; final cy1 = size.height / 2;
        for (int i = 0; i < 6; i++) {
          final angle = i * pi / 3 + t * 2 * pi;
          final r = 80.0;
          final colors = [const Color(0xAAFF00FF), const Color(0xAA00FFFF), const Color(0xAAFFFF00)];
          final path = Path()
            ..moveTo(cx1, cy1)
            ..lineTo(cx1 + cos(angle) * r, cy1 + sin(angle) * r)
            ..lineTo(cx1 + cos(angle + pi / 3) * r, cy1 + sin(angle + pi / 3) * r)
            ..close();
          canvas.drawPath(path, Paint()..color = colors[i % 3].withOpacity(0.12 * intensity));
        }
        break;

      case 'fisheye':
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..shader = RadialGradient(
              colors: [Colors.transparent, Colors.black.withOpacity(0.18 * intensity)],
              stops: const [0.6, 1.0],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
        break;

      case 'heat_wave':
        for (int i = 0; i < 8; i++) {
          final y = size.height * (i / 8.0);
          canvas.drawRect(Rect.fromLTWH(sin(t * 2 * pi + i * 0.7) * 4 * intensity, y, size.width, size.height / 8),
              Paint()..color = Colors.orange.withOpacity(0.03 * intensity));
        }
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..color = const Color(0xFFFF6E40).withOpacity(0.04 * intensity));
        break;

      case 'pixel_sort':
        final rng3 = Random(99);
        for (int i = 0; i < (intensity * 10).toInt(); i++) {
          final y = rng3.nextDouble() * size.height;
          final w = rng3.nextDouble() * size.width * 0.5 * intensity;
          canvas.drawRect(Rect.fromLTWH(rng3.nextDouble() * size.width * 0.5, y, w, 2 + rng3.nextDouble() * 2),
              Paint()..color = HSVColor.fromAHSV(0.5 * intensity, rng3.nextDouble() * 360, 1.0, 1.0).toColor());
        }
        break;

    // ════════════════════════════════
    // 📼 RETRO
    // ════════════════════════════════

      case 'vhs':
        for (double y = 0; y < size.height; y += 3) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y),
              Paint()..color = Colors.black.withOpacity(0.06 * intensity)..strokeWidth = 1);
        }
        final rng4 = Random(77);
        for (int i = 0; i < (intensity * 30).toInt(); i++) {
          canvas.drawCircle(
              Offset(rng4.nextDouble() * size.width, rng4.nextDouble() * size.height),
              0.8, Paint()..color = Colors.white.withOpacity(0.3 * intensity));
        }
        break;

      case 'bwfilm':
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..color = Colors.grey.withOpacity(0.3 * intensity)..blendMode = BlendMode.saturation);
        break;

      case 'oldmovie':
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..color = const Color(0xFFFF8F00).withOpacity(0.10 * intensity));
        for (double y = 0; y < size.height; y += 3) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y),
              Paint()..color = Colors.black.withOpacity(0.05 * intensity)..strokeWidth = 1);
        }
        break;

      case 'film_grain':
        final rng5 = Random(123);
        for (int i = 0; i < (intensity * 600).toInt(); i++) {
          canvas.drawCircle(
              Offset(rng5.nextDouble() * size.width, rng5.nextDouble() * size.height),
              0.6, Paint()..color = (rng5.nextDouble() > 0.5 ? Colors.white : Colors.black)
              .withOpacity(rng5.nextDouble() * 0.18 * intensity));
        }
        break;

      case 'crt':
        for (double y = 0; y < size.height; y += 3) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y),
              Paint()..color = Colors.black.withOpacity(0.15 * intensity)..strokeWidth = 1.5);
        }
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..shader = RadialGradient(
              colors: [Colors.transparent, Colors.black.withOpacity(0.3 * intensity)],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
        break;

      case 'vignette':
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..shader = RadialGradient(
              colors: [Colors.transparent, Colors.black.withOpacity(0.75 * intensity)],
              stops: const [0.5, 1.0],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
        break;

      case 'retro_wave':
        for (int i = 0; i < 5; i++) {
          final y = size.height * 0.55 + i * 20.0;
          final paint = Paint()
            ..color = Color.lerp(const Color(0xFFFF0080), const Color(0xFF00FFFF), i / 5)!
                .withOpacity(0.35 * intensity)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke;
          final path = Path()..moveTo(0, y);
          for (double x = 0; x < size.width; x += 5) {
            path.lineTo(x, y + sin(x / 30) * 10 * intensity);
          }
          canvas.drawPath(path, paint);
        }
        break;

      case 'duotone':
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..shader = LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [
                const Color(0xFF7B1FA2).withOpacity(0.25 * intensity),
                const Color(0xFFFF4081).withOpacity(0.25 * intensity),
              ],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
        break;

      case 'hologram':
        for (int i = 0; i < 8; i++) {
          final y = (i * size.height / 8 + size.height * 0.2) % size.height;
          canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2),
              Paint()..color = const Color(0xFF00E5FF).withOpacity(0.12 * intensity));
        }
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..color = const Color(0xFF00E5FF).withOpacity(0.04 * intensity));
        break;

      case 'noise_static':
        final rng6 = Random(555);
        for (int i = 0; i < (intensity * 1500).toInt(); i++) {
          canvas.drawRect(
              Rect.fromLTWH(rng6.nextDouble() * size.width, rng6.nextDouble() * size.height, 2, 2),
              Paint()..color = (rng6.nextDouble() > 0.5 ? Colors.white : Colors.black)
                  .withOpacity(rng6.nextDouble() * 0.3 * intensity));
        }
        break;

      case 'light_leak':
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..shader = RadialGradient(
              center: Alignment.topLeft,
              colors: [
                const Color(0xFFFFD180).withOpacity(0.4 * intensity),
                Colors.transparent,
              ],
              radius: 1.2,
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..shader = RadialGradient(
              center: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF6D00).withOpacity(0.3 * intensity),
                Colors.transparent,
              ],
              radius: 1.0,
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
        break;

      case 'vaporwave':
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..shader = LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFEA80FC).withOpacity(0.15 * intensity),
                const Color(0xFF40C4FF).withOpacity(0.10 * intensity),
              ],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
        final horizon = size.height * 0.55;
        for (int i = 1; i <= 6; i++) {
          final y = horizon + (size.height - horizon) * (i / 6.0);
          canvas.drawLine(Offset(0, y), Offset(size.width, y),
              Paint()..color = const Color(0xFFEA80FC).withOpacity(0.3 * intensity * (i / 6)));
        }
        break;

    // ════════════════════════════════
    // 🌿 NATURE
    // ════════════════════════════════

      case 'rain':
        final rng7 = Random(42);
        for (int i = 0; i < (intensity * 50).toInt(); i++) {
          final x = rng7.nextDouble() * size.width;
          final y = rng7.nextDouble() * size.height;
          canvas.drawLine(Offset(x, y), Offset(x - 1.5, y + 14),
              Paint()..color = Colors.lightBlueAccent.withOpacity(0.45 * intensity)..strokeWidth = 1.2);
        }
        break;

      case 'snow':
        final rng8 = Random(99);
        for (int i = 0; i < (intensity * 40).toInt(); i++) {
          final x = rng8.nextDouble() * size.width;
          final y = rng8.nextDouble() * size.height;
          canvas.drawCircle(Offset(x, y), 1.5 + rng8.nextDouble() * 2,
              Paint()..color = Colors.white.withOpacity(0.75 * intensity));
        }
        break;

      case 'lensflare':
        final cx2 = size.width * 0.7; final cy2 = size.height * 0.2;
        for (final r in [80.0, 50.0, 30.0, 15.0]) {
          canvas.drawCircle(Offset(cx2, cy2), r,
              Paint()
                ..color = const Color(0xFFFFFDE7).withOpacity(0.25 * intensity)
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5));
        }
        break;

      case 'fireflies':
        final rng9 = Random(77);
        for (int i = 0; i < (intensity * 20).toInt(); i++) {
          canvas.drawCircle(
              Offset(rng9.nextDouble() * size.width, rng9.nextDouble() * size.height),
              3, Paint()
            ..color = const Color(0xFFFFEB3B).withOpacity(0.7 * intensity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        }
        break;

      case 'petals':
        final rng10 = Random(33);
        final petalColors = [const Color(0xFFFFB3BA), const Color(0xFFFFD1DC), const Color(0xFFFFC0CB)];
        for (int i = 0; i < (intensity * 15).toInt(); i++) {
          final x = rng10.nextDouble() * size.width;
          final y = rng10.nextDouble() * size.height;
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(rng10.nextDouble() * 2 * pi);
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 8, height: 14),
              Paint()..color = petalColors[i % 3].withOpacity(0.65 * intensity));
          canvas.restore();
        }
        break;

      case 'aurora':
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..shader = LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF00E676).withOpacity(0.20 * intensity),
                const Color(0xFF00BCD4).withOpacity(0.15 * intensity),
                const Color(0xFF7C4DFF).withOpacity(0.10 * intensity),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3, 0.6, 1.0],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
        break;

      case 'fog':
        for (int i = 0; i < 3; i++) {
          canvas.drawOval(
              Rect.fromCenter(
                  center: Offset(size.width * (0.3 + i * 0.2), size.height * 0.5),
                  width: size.width * 0.6,
                  height: size.height * 0.3),
              Paint()
                ..color = Colors.white.withOpacity(0.07 * intensity)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40));
        }
        break;

      case 'lightning':
        final rng11 = Random(111);
        final lp = Paint()
          ..color = Colors.yellow.withOpacity(0.6 * intensity)
          ..strokeWidth = 2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        double lx = rng11.nextDouble() * size.width;
        double ly = 0;
        while (ly < size.height) {
          final nx = lx + (rng11.nextDouble() - 0.5) * 40;
          final ny = ly + 20 + rng11.nextDouble() * 20;
          canvas.drawLine(Offset(lx, ly), Offset(nx, ny), lp);
          lx = nx; ly = ny;
        }
        break;

      case 'underwater':
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..color = const Color(0xFF006064).withOpacity(0.18 * intensity));
        final rng12 = Random(11);
        for (int i = 0; i < (intensity * 12).toInt(); i++) {
          canvas.drawCircle(
              Offset(rng12.nextDouble() * size.width, rng12.nextDouble() * size.height),
              2 + rng12.nextDouble() * 4,
              Paint()
                ..color = Colors.white.withOpacity(0.20 * intensity)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
        }
        break;

      case 'stars':
        final rng13 = Random(21);
        for (int i = 0; i < (intensity * 50).toInt(); i++) {
          canvas.drawCircle(
              Offset(rng13.nextDouble() * size.width, rng13.nextDouble() * size.height),
              1 + rng13.nextDouble() * 1.5,
              Paint()..color = Colors.white.withOpacity(0.7 * intensity));
        }
        break;

      case 'bokeh':
        final rng14 = Random(44);
        final bokehColors = [const Color(0xFFFFECB3), const Color(0xFFB3E5FC), const Color(0xFFE1BEE7)];
        for (int i = 0; i < (intensity * 15).toInt(); i++) {
          final r = 12 + rng14.nextDouble() * 28;
          canvas.drawCircle(
              Offset(rng14.nextDouble() * size.width, rng14.nextDouble() * size.height),
              r,
              Paint()
                ..color = bokehColors[i % 3].withOpacity(0.25 * intensity)
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6));
        }
        break;

      case 'warp_speed':
        final cx3 = size.width / 2; final cy3 = size.height / 2;
        final rng15 = Random(55);
        for (int i = 0; i < (intensity * 50).toInt(); i++) {
          final angle = rng15.nextDouble() * 2 * pi;
          final startR = rng15.nextDouble() * size.width * 0.3;
          final endR = startR + 20 + 40 * intensity;
          canvas.drawLine(
              Offset(cx3 + cos(angle) * startR, cy3 + sin(angle) * startR),
              Offset(cx3 + cos(angle) * endR, cy3 + sin(angle) * endR),
              Paint()
                ..color = Colors.white.withOpacity((1 - startR / size.width).clamp(0.0, 1.0) * intensity)
                ..strokeWidth = 1.0);
        }
        break;

    // ════════════════════════════════
    // 🎉 PARTY
    // ════════════════════════════════

      case 'neon':
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..shader = LinearGradient(
              colors: [
                Colors.pinkAccent.withOpacity(0.08 * intensity),
                Colors.transparent,
                Colors.purpleAccent.withOpacity(0.08 * intensity),
              ],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
        break;

      case 'sparkle':
        final rng16 = Random(55);
        for (int i = 0; i < (intensity * 18).toInt(); i++) {
          final cx4 = rng16.nextDouble() * size.width;
          final cy4 = rng16.nextDouble() * size.height;
          final r = 6.0 + rng16.nextDouble() * 6;
          final sp = Paint()..color = Colors.yellow.withOpacity(0.7 * intensity)..strokeWidth = 1.5..strokeCap = StrokeCap.round;
          for (int j = 0; j < 4; j++) {
            final ang = j * pi / 4;
            canvas.drawLine(Offset(cx4 - cos(ang) * r, cy4 - sin(ang) * r),
                Offset(cx4 + cos(ang) * r, cy4 + sin(ang) * r), sp);
          }
        }
        break;

      case 'confetti':
        final rng17 = Random(88);
        final confColors = [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.pink, Colors.orange];
        for (int i = 0; i < (intensity * 35).toInt(); i++) {
          final x = rng17.nextDouble() * size.width;
          final y = rng17.nextDouble() * size.height;
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(rng17.nextDouble() * 2 * pi);
          canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 6, height: 10),
              Paint()..color = confColors[i % confColors.length].withOpacity(0.75 * intensity));
          canvas.restore();
        }
        break;

      case 'disco':
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..color = HSVColor.fromAHSV(0.12 * intensity, 180, 1.0, 1.0).toColor());
        break;

      case 'laser':
        final lp2 = Paint()
          ..color = const Color(0xFF76FF03).withOpacity(0.45 * intensity)
          ..strokeWidth = 1
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
        for (double x = 0; x < size.width; x += 30) canvas.drawLine(Offset(x, 0), Offset(x, size.height), lp2);
        for (double y = 0; y < size.height; y += 30) canvas.drawLine(Offset(0, y), Offset(size.width, y), lp2);
        break;

      case 'hearts':
        final rng18 = Random(66);
        for (int i = 0; i < (intensity * 12).toInt(); i++) {
          final x = rng18.nextDouble() * size.width;
          final y = rng18.nextDouble() * size.height;
          final s = 6 + rng18.nextDouble() * 8;
          final path = Path()
            ..moveTo(x, y + s * 0.3)
            ..cubicTo(x - s, y - s * 0.5, x - s * 1.5, y + s * 0.5, x, y + s)
            ..cubicTo(x + s * 1.5, y + s * 0.5, x + s, y - s * 0.5, x, y + s * 0.3);
          canvas.drawPath(path, Paint()..color = const Color(0xFFFF1744).withOpacity(0.65 * intensity));
        }
        break;

      case 'bubbles':
        final rng19 = Random(55);
        for (int i = 0; i < (intensity * 18).toInt(); i++) {
          final r = 4 + rng19.nextDouble() * 12;
          canvas.drawCircle(
              Offset(rng19.nextDouble() * size.width, rng19.nextDouble() * size.height),
              r,
              Paint()
                ..color = const Color(0xFF40C4FF).withOpacity(0.28 * intensity)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5);
        }
        break;

      case 'explosion':
        final cx5 = size.width / 2; final cy5 = size.height / 2;
        for (int i = 0; i < 12; i++) {
          final angle = i * pi / 6;
          canvas.drawLine(Offset(cx5, cy5),
              Offset(cx5 + cos(angle) * 80 * intensity, cy5 + sin(angle) * 80 * intensity),
              Paint()
                ..color = Colors.orange.withOpacity(0.55 * intensity)
                ..strokeWidth = 2.5
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
        }
        break;

      case 'rainbow':
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..shader = LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: List.generate(7, (i) =>
                  HSVColor.fromAHSV(0.12 * intensity, i * 51.4, 1.0, 1.0).toColor()),
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
        break;

      case 'matrix':
        final rng20 = Random(999);
        const matChars = '01アイウ01カキ01';
        for (double x = 0; x < size.width; x += 14) {
          for (int i = 0; i < (intensity * 6).toInt(); i++) {
            final y = rng20.nextDouble() * size.height;
            final char = matChars[rng20.nextInt(matChars.length)];
            final tp = TextPainter(
              text: TextSpan(text: char, style: TextStyle(
                  color: const Color(0xFF00E676).withOpacity(rng20.nextDouble() * intensity),
                  fontSize: 12)),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(canvas, Offset(x, y));
          }
        }
        break;

      case 'glitter':
        final rng21 = Random(12345);
        for (int i = 0; i < (intensity * 100).toInt(); i++) {
          final cx6 = rng21.nextDouble() * size.width;
          final cy6 = rng21.nextDouble() * size.height;
          final bright = rng21.nextDouble();
          if (bright > 0.5) {
            final r = 2 + rng21.nextDouble() * 4;
            final gp = Paint()
              ..color = Color.lerp(const Color(0xFFFFD54F), Colors.white, bright)!
                  .withOpacity(bright * intensity)
              ..strokeWidth = 1;
            canvas.drawLine(Offset(cx6 - r, cy6), Offset(cx6 + r, cy6), gp);
            canvas.drawLine(Offset(cx6, cy6 - r), Offset(cx6, cy6 + r), gp);
          }
        }
        break;

    // ════════════════════════════════
    // 🔮 AESTHETIC
    // ════════════════════════════════

      case 'dreamy':
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..shader = RadialGradient(
              colors: [
                const Color(0xFFCE93D8).withOpacity(0.18 * intensity),
                const Color(0xFF80DEEA).withOpacity(0.12 * intensity),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
        break;

      case 'lofi':
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..shader = RadialGradient(
              colors: [Colors.transparent, Colors.black.withOpacity(0.35 * intensity)],
              stops: const [0.5, 1.0],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..color = const Color(0xFFA5D6A7).withOpacity(0.06 * intensity));
        break;

      case 'prism':
        final cx7 = size.width / 2; final cy7 = size.height / 2;
        for (int i = 0; i < 5; i++) {
          final angle = t * 2 * pi + i * pi / 5;
          canvas.drawLine(Offset(cx7, cy7),
              Offset(cx7 + cos(angle) * size.width, cy7 + sin(angle) * size.height),
              Paint()
                ..color = HSVColor.fromAHSV(0.18 * intensity, (i * 72 + 180) % 360, 1.0, 1.0).toColor()
                ..strokeWidth = 2
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        }
        break;

      case 'glimmer':
        final rng22 = Random(12);
        for (int i = 0; i < (intensity * 12).toInt(); i++) {
          canvas.drawCircle(
              Offset(rng22.nextDouble() * size.width, rng22.nextDouble() * size.height),
              8 + 4.0 * t,
              Paint()
                ..color = Colors.white.withOpacity(0.5 * intensity)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        }
        break;

      case 'portal':
        final cx8 = size.width / 2; final cy8 = size.height / 2;
        for (int i = 5; i >= 1; i--) {
          canvas.drawCircle(Offset(cx8, cy8), size.width * 0.1 * i,
              Paint()
                ..color = const Color(0xFF1DE9B6).withOpacity((1 - i / 6.0) * 0.22 * intensity)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2);
        }
        break;

      case 'smoke':
        final rng23 = Random(99);
        for (int i = 0; i < (intensity * 6).toInt(); i++) {
          final x = size.width * (0.3 + rng23.nextDouble() * 0.4);
          final y = size.height * (0.2 + rng23.nextDouble() * 0.6);
          canvas.drawCircle(Offset(x, y), 30 + rng23.nextDouble() * 40,
              Paint()
                ..color = Colors.white.withOpacity(0.08 * intensity)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));
        }
        break;

      case 'ink_drop':
        final rng24 = Random(77);
        final inkColors = [const Color(0xFF311B92), const Color(0xFF4527A0), const Color(0xFF7B1FA2)];
        for (int i = 0; i < (intensity * 4).toInt(); i++) {
          canvas.drawCircle(
              Offset(rng24.nextDouble() * size.width, rng24.nextDouble() * size.height),
              30 + rng24.nextDouble() * 30,
              Paint()
                ..color = inkColors[i % 3].withOpacity(0.22 * intensity)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        }
        break;

      case 'crystal':
        final rng25 = Random(33);
        for (int i = 0; i < (intensity * 8).toInt(); i++) {
          final cx9 = rng25.nextDouble() * size.width;
          final cy9 = rng25.nextDouble() * size.height;
          final r = 5 + rng25.nextDouble() * 15;
          final path = Path();
          for (int j = 0; j < 6; j++) {
            final a = j * pi / 3;
            if (j == 0) path.moveTo(cx9 + cos(a) * r, cy9 + sin(a) * r);
            else path.lineTo(cx9 + cos(a) * r, cy9 + sin(a) * r);
          }
          path.close();
          canvas.drawPath(path, Paint()
            ..color = const Color(0xFF80CBC4).withOpacity(0.35 * intensity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
        }
        break;

      case 'fire':
        final rng26 = Random(500);
        for (int i = 0; i < (intensity * 25).toInt(); i++) {
          final x = rng26.nextDouble() * size.width;
          final h = (0.3 + rng26.nextDouble() * 0.5) * size.height * intensity;
          final fireColors = [const Color(0xFFFF3D00), const Color(0xFFFF6D00), const Color(0xFFFFD600)];
          canvas.drawOval(
              Rect.fromCenter(
                  center: Offset(x, size.height - h * 0.5),
                  width: 8 + rng26.nextDouble() * 16,
                  height: 20 + rng26.nextDouble() * 30),
              Paint()
                ..color = fireColors[i % 3].withOpacity(0.35 * intensity)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        }
        break;

      case 'tv_lines':
        for (int i = 0; i < 6; i++) {
          final y = i * size.height / 6 + size.height * 0.1;
          canvas.drawLine(Offset(0, y), Offset(size.width, y),
              Paint()
                ..color = const Color(0xFF546E7A).withOpacity(0.35 * intensity)
                ..strokeWidth = 2);
        }
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..color = const Color(0xFF546E7A).withOpacity(0.04 * intensity));
        break;

      case 'cinematic':
        final barH = size.height * 0.10 * intensity;
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, barH), Paint()..color = Colors.black);
        canvas.drawRect(Rect.fromLTWH(0, size.height - barH, size.width, barH), Paint()..color = Colors.black);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..color = Colors.black.withOpacity(0.07 * intensity));
        break;

      case 'comic':
        final rng27 = Random(12);
        const spacing = 10.0;
        for (double x = 0; x < size.width; x += spacing) {
          for (double y = 0; y < size.height; y += spacing) {
            final r = spacing * 0.45 * (0.3 + rng27.nextDouble() * 0.5) * intensity;
            canvas.drawCircle(Offset(x, y), r, Paint()..color = Colors.black.withOpacity(0.07 * intensity));
          }
        }
        break;

      case 'neon_trails':
        final neonColors = [const Color(0xFF18FFFF), const Color(0xFFE040FB), const Color(0xFF76FF03)];
        final rng28 = Random(66);
        for (int i = 0; i < (intensity * 4).toInt(); i++) {
          final startX = rng28.nextDouble() * size.width;
          final path = Path()..moveTo(startX, size.height);
          for (int j = 0; j < 8; j++) {
            final px = startX + sin(j * 0.5 + i) * 30 * intensity;
            final py = size.height * (1 - j / 8.0 * 0.5);
            path.lineTo(px, py);
          }
          canvas.drawPath(path, Paint()
            ..color = neonColors[i % neonColors.length].withOpacity(0.5 * intensity)
            ..strokeWidth = 2 + intensity * 2
            ..style = PaintingStyle.stroke
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + intensity * 3));
        }
        break;
    }
  }
  Future<String?> _renderOverlayImage({
    required double vidW,
    required double vidH,
    required double scaleX,
    required double scaleY,
  }) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, vidW, vidH));

      // ── Transparent background ──────────────────────────────────────────
      canvas.drawRect(
        Rect.fromLTWH(0, 0, vidW, vidH),
        Paint()..color = Colors.transparent,
      );

      for (final layer in widget.effectLayers) {
        _drawEffectOnCanvas(canvas, Size(vidW, vidH), layer.effectKey, layer.intensity);
      }


      // ── 2. Stickers ────────────────────────────────────────────────────
      for (final sticker in widget.placedStickers) {
        final emoji   = sticker['emoji'] as String;
        final sx      = (sticker['x']     as double) * scaleX;
        final sy      = (sticker['y']     as double) * scaleY;
        final scale   = (sticker['scale'] as double);
        final angle   = (sticker['angle'] as double);
        final fontSize = 52.0 * scaleX * scale;

        final tp = TextPainter(
          text: TextSpan(text: emoji, style: TextStyle(fontSize: fontSize)),
          textDirection: TextDirection.ltr,
        )..layout();

        canvas.save();
        canvas.translate(sx, sy);
        canvas.rotate(angle);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }

      // ── 3. Text Overlays ───────────────────────────────────────────────
      for (final overlay in widget.textOverlays) {
        Color overlayColor = Colors.white;
        FontWeight weight  = FontWeight.normal;
        FontStyle  style   = FontStyle.normal;
        try {
          final dynamic d = overlay;
          Color? c;
          try { c = d.textColor as Color?; } catch (_) {}
          if (c == null) { try { c = d.color as Color?; } catch (_) {} }
          if (c != null) overlayColor = c;
          try { if (d.isBold   == true) weight = FontWeight.bold;   } catch (_) {}
          try { if (d.isItalic == true) style  = FontStyle.italic;  } catch (_) {}
        } catch (_) {}

        final tp = TextPainter(
          text: TextSpan(
            text: overlay.text,
            style: TextStyle(
              fontSize:   (overlay.fontSize * scaleX).clamp(10.0, 300.0),
              color:      overlayColor,
              fontWeight: weight,
              fontStyle:  style,
              shadows: const [Shadow(color: Colors.black54, offset: Offset(2,2), blurRadius: 4)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: vidW);

        tp.paint(canvas, Offset(
          (overlay.x * scaleX).clamp(0.0, vidW - 1),
          (overlay.y * scaleY).clamp(0.0, vidH - 1),
        ));
      }

      // ── PNG export ─────────────────────────────────────────────────────
      final picture  = recorder.endRecording();
      final img      = await picture.toImage(vidW.toInt(), vidH.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final bytes    = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final path    = '${tempDir.path}/overlay_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(bytes);
      return path;
    } catch (e) {
      debugPrint('❌ Overlay render error: $e');
      return null;
    }
  }

// 📍 PostActivity.dart - Line ~973 අවට REPLACE කරන්න

  String _applyCloudinaryTransformations(String cloudinaryUrl, bool isVideo) {
    try {
      if (isVideo) {
        debugPrint('🎥 Video: No client-side transformations applied');
        return cloudinaryUrl;
      } else {
        // ✅ FIX: Rendered image already has edits baked in
        // Cloudinary transforms add කරන්න එපා — f_auto convert කරනකොට edits lose වෙනවා
        debugPrint('🖼️ Image: Using original URL (edits already baked in rendered file)');
        return cloudinaryUrl;
      }
    } catch (e) {
      debugPrint('❌ Error applying transformations: $e');
      return cloudinaryUrl;
    }
  }

// 👇 මෙතනට add කරන්න - නව method එක
  String? _generateThumbnailUrl(String cloudinaryUrl) {
    debugPrint('\n🖼️ ========== THUMBNAIL GENERATION (DART) ==========');
    debugPrint('   Input URL: $cloudinaryUrl');
    debugPrint('   Is Video: $_isVideo');

    try {
      if (!cloudinaryUrl.contains('cloudinary.com')) {
        debugPrint('   ❌ FAILED: Not a Cloudinary URL');
        debugPrint('==========================================\n');
        return null;
      }
      if (!cloudinaryUrl.contains('/upload/')) {
        debugPrint('   ❌ FAILED: No /upload/ in URL');
        debugPrint('==========================================\n');
        return null;
      }

      const transformations = 'so_auto,w_400,h_711,c_fill,q_auto,f_jpg';

      String thumbnailUrl = cloudinaryUrl
          .replaceFirst('/upload/', '/upload/$transformations/')
          .replaceAll(
        RegExp(r'\.(mp4|mov|avi|mkv|webm)$', caseSensitive: false),
        '.jpg',
      );

      debugPrint('   ✅ SUCCESS!');
      debugPrint('   Thumbnail URL: $thumbnailUrl');
      debugPrint('==========================================\n');
      return thumbnailUrl;
    } catch (e) {
      debugPrint('   ❌ EXCEPTION: $e');
      debugPrint('==========================================\n');
      return null;
    }
  }
// ✅ Multi-image parallel upload to Cloudinary
// දාන්න ඕන: _uploadMediaToCloudinary() method එකට ඉස්සරහින්
  Future<List<String>> _uploadMultipleImagesToCloudinary(List<File> imageFiles) async {
    final cloudinary = CloudinaryPublic(
      CLOUDINARY_CLOUD_NAME,
      'user_uploads',
      cache: false,
    );

    setState(() {
      _uploadProgress = 40;
      _uploadStatus = 'Uploading ${imageFiles.length} images...';
    });

    // ✅ Parallel upload - Future.wait() නිසා එකපාරම upload වෙනවා
    final uploadFutures = imageFiles.map((file) async {
      return await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
    }).toList();

    final results = await Future.wait(uploadFutures);

    // ✅ Cloudinary URL list return කරනවා
    final urls = results.map((r) => r.secureUrl).toList();
    debugPrint('✅ Uploaded ${urls.length} images: $urls');
    return urls;
  }
  Future<void> _uploadMediaToCloudinary(File mediaFile,
      String description) async {
    try {
      debugPrint('🚀 Starting Cloudinary upload...');

      setState(() {
        _uploadProgress = 15;
        _uploadStatus = 'Preparing file...';
      });

      // Re-check connectivity
      if (!await _isNetworkAvailable()) {
        setState(() {
          _showUploadDialog = false;
        });
        _showErrorDialog('Network connection lost during upload');
        return;
      }

      final mimeType = lookupMimeType(mediaFile.path);
      final isVideo = mimeType != null && mimeType.startsWith('video');

      debugPrint('📄 MIME Type: $mimeType | Is Video: $isVideo');

      setState(() {
        _uploadProgress = 20;
        _uploadStatus = 'Reading file data...';
      });

      final fileBytes = await mediaFile.readAsBytes();
      debugPrint('📁 File size: ${fileBytes.length} bytes');

      if (fileBytes.isEmpty) {
        setState(() {
          _showUploadDialog = false;
        });
        _showErrorDialog('File is empty or corrupted');
        return;
      }

      // Check file size limit (50MB)
      if (fileBytes.length > 50 * 1024 * 1024) {
        setState(() {
          _showUploadDialog = false;
        });
        _showErrorDialog('File too large. Maximum size is 50MB');
        return;
      }

      setState(() {
        _uploadProgress = 35;
        _uploadStatus = 'Connecting to server...';
      });

      final cloudinary = CloudinaryPublic(
        CLOUDINARY_CLOUD_NAME,
        'user_uploads',
        cache: false,
      );

      setState(() {
        _uploadProgress = 40;
        _uploadStatus = 'Uploading to cloud...';
      });

      CloudinaryResponse? uploadResult;
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries && uploadResult == null) {
        try {
          final currentAttempt = retryCount + 1;
          setState(() {
            _uploadProgress = 40 + (retryCount * 15);
            _uploadStatus =
            'Uploading... (attempt $currentAttempt of $maxRetries)';
          });

          if (isVideo) {
            uploadResult = await cloudinary.uploadFile(
              CloudinaryFile.fromFile(
                mediaFile.path,
                resourceType: CloudinaryResourceType.Video,
              ),
            );
          } else {
            uploadResult = await cloudinary.uploadFile(
              CloudinaryFile.fromFile(
                mediaFile.path,
                resourceType: CloudinaryResourceType.Image,
              ),
            );
          }

          debugPrint('✅ Upload successful on attempt $currentAttempt');
          debugPrint('📤 Uploaded URL: ${uploadResult.secureUrl}');
          debugPrint('🆔 Public ID: ${uploadResult.publicId}');

          setState(() {
            _uploadProgress = 80;
            _uploadStatus = 'Upload completed, processing...';
          });
          break;
        } catch (e) {
          retryCount++;
          debugPrint('❌ Upload attempt $retryCount failed: $e');

          if (e is Exception) {
            debugPrint('❌ Exception details: ${e.toString()}');
          }

          if (retryCount < maxRetries) {
            final waitTime = Duration(milliseconds: 1000 * retryCount);
            setState(() {
              _uploadStatus = 'Retrying in ${waitTime.inSeconds}s...';
            });
            await Future.delayed(waitTime);
          } else {
            throw e;
          }
        }
      }

      if (uploadResult == null || uploadResult.secureUrl.isEmpty) {
        setState(() {
          _showUploadDialog = false;
        });
        _showErrorDialog('Upload failed: Invalid response from server');
        return;
      }

      // ✅ APPLY CLOUDINARY TRANSFORMATIONS TO URL
      final originalUrl = uploadResult.secureUrl;
      final optimizedUrl = _applyCloudinaryTransformations(
          originalUrl, isVideo);

      debugPrint('🔗 Original URL: $originalUrl');
      debugPrint('✨ Optimized URL: $optimizedUrl');

      final publicId = uploadResult.publicId;

      debugPrint('✅ Cloudinary upload successful!');
      debugPrint('🔗 URL with transformations: $optimizedUrl');
      debugPrint('🆔 Public ID: $publicId');

      setState(() {
        _uploadProgress = 90;
        _uploadStatus = 'Saving post...';
      });

      // Send to backend with optimized URL
      await _sendPostToBackend(
        optimizedUrl,
        publicId,
        description,
        isVideo ? 'video' : 'image',
      );
    } catch (e) {
      debugPrint('❌ Cloudinary upload failed: $e');
      setState(() {
        _showUploadDialog = false;
      });

      String errorMessage = 'Upload failed';
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('network') || errorStr.contains('host') ||
          errorStr.contains('dns')) {
        errorMessage = 'Network error. Please check your internet connection';
      } else if (errorStr.contains('timeout')) {
        errorMessage = 'Upload timeout. Please try again';
      } else if (errorStr.contains('ssl') || errorStr.contains('certificate')) {
        errorMessage = 'SSL connection error. Please try again';
      } else {
        errorMessage = 'Upload failed: $e';
      }

      _showErrorDialog(errorMessage);
    }
  }

// PostActivity.dart ගොනුවේ _sendTagNotifications() method එකට පෙර add කරන්න

  /// Mentioned users ට notification යවන්න
  Future<void> _sendMentionNotifications(String postId) async {
    final mentionedUserIds = _extractMentionedUserIds();

    if (mentionedUserIds.isEmpty) {
      debugPrint('⚠️ No mentioned users to notify');
      return;
    }

    try {
      debugPrint('📤 Sending mention notifications to ${mentionedUserIds
          .length} users...');

      final notificationData = {
        'postId': postId,
        'senderUid': currentUserId,
        'senderUsername': currentUsername,
        'mentionedUserIds': mentionedUserIds,
        'mentionType': 'post_mention',
        'timestamp': DateTime
            .now()
            .millisecondsSinceEpoch,
      };

      final response = await http.post(
        Uri.parse('$BACKEND_URL/api/send-mention-notifications'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(notificationData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('✅ Mention notifications sent successfully');
      } else {
        debugPrint('⚠️ Mention notifications failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error sending mention notifications: $e');
      // Don't fail the entire post if notifications fail
    }
  }

  // ✅ SEND NOTIFICATIONS TO TAGGED FRIENDS
  Future<void> _sendTagNotifications(String postId) async {
    if (taggedFriendUIDs.isEmpty) {
      debugPrint('⚠️ No tagged friends to notify');
      return;
    }

    try {
      debugPrint('📤 Sending tag notifications to ${taggedFriendUIDs
          .length} friends...');

      final notificationData = {
        'sender_uid': currentUserId,
        'sender_username': currentUsername,
        'post_id': postId,
        'tagged_users': taggedFriendUIDs,
        'timestamp': DateTime
            .now()
            .millisecondsSinceEpoch,
      };

      final response = await http.post(
        Uri.parse('$BACKEND_URL/api/send-tag-notifications'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(notificationData),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Tag notifications sent successfully');
      } else {
        debugPrint('⚠️ Tag notifications failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error sending tag notifications: $e');
      // Don't fail the entire post if notifications fail
    }
  }

  Future<void> _sendPostToBackend(String mediaUrl,
      String publicId,
      String description,
      String mediaType,) async {
    try {
      if (currentUserId == null || currentUsername == null) {
        throw Exception('User information not available');
      }

      // Extract hashtags from description
      _extractHashtagsFromDescription(description);

      // Prepare hashtags string
      final hashtagsString = selectedHashtags.join(',');

      // ✅ UPDATED: Extract mentioned user IDs
      final mentionedUserIds = _extractMentionedUserIds();
      final mentionedUsersJson = jsonEncode(
        mentionedUsers.map((user) =>
        {
          'uid': user['uid'],
          'username': user['username'],
        }).toList(),
      );

      // ✅ Send only UIDs for tagged friends (not full objects!)
      final taggedFriendsJson = jsonEncode(taggedFriendUIDs);

      // Map privacy correctly
      String backendPrivacy = selectedPrivacy.toLowerCase();
      if (backendPrivacy == 'only me') {
        backendPrivacy = 'onlyme';
      }
// ✅ Generate thumbnail BEFORE requestBody
        final thumbnailUrl = _isVideo ? _generateThumbnailUrl(mediaUrl) : null;

// 🎵 Sound URL - Cloudinary on-the-fly transform (වෙනම upload නෑ!)
      String? finalSoundUrl;

      if (selectedSoundUrl != null &&
          selectedSoundUrl!.startsWith('http')) {
        // User selected existing sound from library → directly use
        finalSoundUrl = selectedSoundUrl;
        debugPrint('🎵 Using existing sound URL: $finalSoundUrl');
      } else if (mediaUrl.contains('cloudinary.com') && _isVideo) {
        // .mp3 වලට මාරු කරන අතරේ ගුණාත්මකභාවය (Bitrate) පාලනය කරන parameters එකතු කිරීම
        // උදාහරණය: 'q_auto' (Quality auto) හෝ 'br_128k' (Bitrate 128kbps)
        final String optimizedBase = mediaUrl.replaceAll('/upload/', '/upload/q_auto,br_128k/');

        finalSoundUrl = optimizedBase.replaceAll(
          RegExp(r'\.(mp4|mov|avi|mkv|webm)$', caseSensitive: false),
          '.mp3',
        );

        debugPrint('🎵 Sound URL from video (on-the-fly): $finalSoundUrl');
      } else {
        // Image post + no music = no sound URL
        finalSoundUrl = null;
        debugPrint('🎵 No sound URL');
      }

        debugPrint('🎵 Final sound URL: $finalSoundUrl');
        debugPrint('\n📦 ========== REQUEST BODY CHECK ==========');
        debugPrint('   media_url: $mediaUrl');
        debugPrint('   type: ${_isVideo ? "video" : "image"}');
        debugPrint('   thumbnail_url: $thumbnailUrl');
        debugPrint('==========================================\n');
      // ✅ UPDATED: Include mentioned_user_ids in request
      final requestBody = {
        'uid': currentUserId,
        'title': _titleController.text.trim(),   // ✅ ADD THIS LINE
        'username': currentUsername,
        'user_email': currentUserEmail,

        'media_url': mediaUrl,   // ✅ backend validation pass කරන්න
        // ✅ media_url line ට පස්සේ මේක add කරන්න
        'media_urls': _uploadedMediaUrls.isNotEmpty
            ? _uploadedMediaUrls          // ✅ parallel upload කරපු real URLs
            : [mediaUrl],                 // ✅ single image නම් array එකක්
        'type': mediaType,
        'cloudinary_public_id': publicId,
        'description': description,
        'who_can_view': backendPrivacy,
        'timestamp': DateTime
            .now()
            .millisecondsSinceEpoch,
        'allowDuet': isDuetAllowed,
        'allowSave': isSaveAllowed,
        'allowComment': isCommentAllowed,
        'saveToDevice': isSaveToDevice,
        'hashtags': hashtagsString,
        'mentioned_friends': mentionedUsersJson, // ✅ Full user objects
        'mentioned_user_ids': mentionedUserIds, // ✅ NEW: Only UIDs array
        'tagged_friends': taggedFriendsJson,
        'sound_url': finalSoundUrl,  // ← selectedSoundUrl වෙනුවට
        'category': selectedCategory ?? 'Other',
        'thumbnail_url': thumbnailUrl, // ✅ මේකයි හරි
        // 🆕 Add these lines:
        'audio_id': selectedAudioId ?? 'original_${currentUserId}',
        'audio_name': selectedAudioName ?? 'Original Sound',
        'album_art_url': selectedAlbumArt,



      };

      debugPrint('📤 Sending to backend...');
      debugPrint('📋 Request UID: $currentUserId');
      debugPrint('📋 Request Username: $currentUsername');
      debugPrint('👤 Mentioned User IDs: $mentionedUserIds');
      debugPrint('🔗 Media URL (with transformations): $mediaUrl');
      debugPrint('👥 Tagged Friends UIDs: $taggedFriendUIDs');
      debugPrint('📋 Full Request: ${jsonEncode(requestBody)}');

      setState(() {
        _uploadProgress = 95;
        _uploadStatus = 'Finalizing post...';
      });

      final response = await http.post(
        Uri.parse('$BACKEND_URL/uploadMedia'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      debugPrint('📥 Response Status: ${response.statusCode}');
      debugPrint('📥 Response Body: ${response.body}');

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final postId = responseData['post_id'] ?? responseData['postId'];

        setState(() {
          _uploadProgress = 100;
          _uploadStatus = 'Post uploaded successfully!';
        });

        // ✅ මෙතනට notification code දාන්න 👇
        await MediaUploadHelper().saveMedia(
          downloadUrl: mediaUrl,
          type: mediaType,           // 'video' හෝ 'image'
          thumbnailUrl: _isVideo ? _generateThumbnailUrl(mediaUrl) : null,
          caption: description,
        );
        // ✅ Send notifications to tagged friends
        if (taggedFriendUIDs.isNotEmpty && postId != null) {
          await _sendTagNotifications(postId);
        }
        // ✅ NEW: Send notifications to mentioned users
        if (mentionedUserIds.isNotEmpty && postId != null) {
          await _sendMentionNotifications(postId);
        }


        await Future.delayed(const Duration(seconds: 1));

        setState(() {
          _showUploadDialog = false;
        });

        _showSnackBar('Post uploaded successfully!', isSuccess: true);

        // ✅ Show tagged friends notification
        if (taggedFriends.isNotEmpty) {
          _showSnackBar(
            '${taggedFriends.length} friend(s) tagged and notified!',
            isSuccess: true,
          );
        }
        // ✅ Show mentioned users notification
        if (mentionedUsers.isNotEmpty) {
          _showSnackBar(
            '${mentionedUsers.length} user(s) mentioned and notified!',
            isSuccess: true,
          );
        }


        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        final errorMessage = responseData['message'] ?? 'Upload failed';
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('🛑 ================== UPLOAD ERROR ==================');
      debugPrint('🛑 Error Type: ${e.runtimeType}');
      debugPrint('🛑 Error Message: $e');
      debugPrint('🛑 =================================================');

      setState(() {
        _showUploadDialog = false;
      });
      _showErrorDialog('Failed to save post: ${e.toString()}');
    }
  }

  /// Description එකෙන් mentioned user IDs ගන්න
  List<String> _extractMentionedUserIds() {
    final mentionedIds = <String>[];
    for (var user in mentionedUsers) {
      final uid = user['uid'] as String?;
      if (uid != null && uid.isNotEmpty) {
        mentionedIds.add(uid);
      }
    }
    debugPrint('📝 Extracted mentioned user IDs: $mentionedIds');
    return mentionedIds;
  }

  // _extractMentionedUserIds() method එකට පස්සේ add කරන්න

  /// Mention කරපු යූසර්ලාගේ නම් list එක ගන්න
  /// Mention කරපු යූසර්ලාගේ නම් list එක ගන්න  👈 মিসিং METHOD
  List<String> _getMentionedUsernames() {
    return mentionedUsers
        .map((user) => user['username'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  /// Description එකෙන් @username pattern ගන්න
  List<String> _extractMentionsFromDescription(String description) {
    final mentionPattern = RegExp(r'@(\w+)');
    final matches = mentionPattern.allMatches(description);
    final mentions = <String>[];

    for (var match in matches) {
      final mention = match.group(1);
      if (mention != null && mention.isNotEmpty) {
        mentions.add('@$mention');
      }
    }

    debugPrint('✅ Extracted mentions from description: $mentions');
    return mentions;
  }

  void _extractHashtagsFromDescription(String description) {
    final words = description.split(' ');
    for (var word in words) {
      if (word.startsWith('#') && word.length > 1) {
        final hashtag = word.trim();
        if (!selectedHashtags.contains(hashtag)) {
          selectedHashtags.add(hashtag);
        }
      }
    }
  }

  Future<void> _saveToDrafts() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _showSnackBar('Nothing to save to drafts');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = {
        'description': description,
        'privacy': selectedPrivacy,
        'hashtags': selectedHashtags.join(','),
        'mentioned_friends': mentionedFriends.join(','),
        'timestamp': DateTime
            .now()
            .millisecondsSinceEpoch,
        'media_uri': _mediaFile?.path ?? '',
      };

      await prefs.setString('current_draft', jsonEncode(draft));
      _showSnackBar('Saved to drafts');
    } catch (e) {
      debugPrint('Error saving draft: $e');
      _showSnackBar('Failed to save draft');
    }
  }

  void _showPrivacyOptions() {
    WhoCanViewBottomSheet.show(
      context,
      currentSelection: selectedPrivacy,
      onPrivacySelected: (String privacy) {
        setState(() {
          selectedPrivacy = privacy;
        });
        debugPrint('Privacy updated to: $privacy');
      },
    );
  }

  void _showMoreOptions() {
    MoreOptionsBottomSheet.show(
      context,
      // ✅ Upload flow = postId null → Firestore update නෑ, callback only
      postId: null,
      currentDuet: isDuetAllowed,
      currentSave: isSaveAllowed,
      currentComment: isCommentAllowed,
      currentSaveDevice: isSaveToDevice,
      onSettingsChanged: (duet, save, comment, saveDevice) {
        setState(() {
          isDuetAllowed    = duet;
          isSaveAllowed    = save;
          isCommentAllowed = comment;
          isSaveToDevice   = saveDevice;
        });
        debugPrint('⚙️ Upload settings — Comment: $comment, Duet: $duet, Save: $save');
      },
    );
  }
  void _showCategoryOptions() {
    final categories = [
      {'name': 'Sports', 'color': const Color(0xFF10B981)},
      {'name': 'News', 'color': const Color(0xFF3B82F6)},
      {'name': 'Politics', 'color': const Color(0xFF8B5CF6)},
      {'name': 'Film', 'color': const Color(0xFFEC4899)},
      {'name': 'Tech', 'color': const Color(0xFF1F2937)},
      {'name': 'Music', 'color': const Color(0xFFF59E0B)},
      {'name': 'Gaming', 'color': const Color(0xFF7C3AED)},
      {'name': 'Food', 'color': const Color(0xFFEF4444)},
      {'name': 'Health', 'color': const Color(0xFF06B6D4)},
      {'name': 'Travel', 'color': const Color(0xFF3B82F6)},
      {'name': 'Money', 'color': const Color(0xFFF59E0B)},
      {'name': 'Fashion', 'color': const Color(0xFFEC4899)},
      {'name': 'Culture', 'color': const Color(0xFF10B981)},
      {'name': 'Science', 'color': const Color(0xFF6366F1)},
      {'name': 'Anime', 'color': const Color(0xFFFF3B5C)},
      {'name': 'LOL', 'color': const Color(0xFFF59E0B)},
      {'name': 'Pets', 'color': const Color(0xFF10B981)},
      {'name': 'Books', 'color': const Color(0xFF8B5CF6)},
      {'name': 'Dance', 'color': const Color(0xFFEC4899)},
      {'name': 'Art', 'color': const Color(0xFF06B6D4)},
      {'name': 'Fitness', 'color': const Color(0xFFEF4444)},
      {'name': 'Comedy', 'color': const Color(0xFFF59E0B)},
      {'name': 'Nature', 'color': const Color(0xFF10B981)},
      {'name': 'Education', 'color': const Color(0xFF3B82F6)},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setSheetState) =>
                Container(
                  height: MediaQuery
                      .of(context)
                      .size
                      .height * 0.65,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.only(top: 14, bottom: 6),
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Title row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Select Category',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            if (selectedCategory != null)
                              GestureDetector(
                                onTap: () {
                                  setState(() => selectedCategory = null);
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF3B5C).withOpacity(
                                        0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFFF3B5C)
                                          .withOpacity(0.4),
                                    ),
                                  ),
                                  child: const Text(
                                    'Clear',
                                    style: TextStyle(
                                      color: Color(0xFFFF3B5C),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      Divider(
                        height: 1,
                        color: Colors.white.withOpacity(0.08),
                        indent: 24,
                        endIndent: 24,
                      ),
                      const SizedBox(height: 16),

                      // Grid of chips
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 2.5,
                            ),
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final name = cat['name'] as String;
                              final color = cat['color'] as Color;
                              final isSelected = selectedCategory == name;

                              return GestureDetector(
                                onTap: () {
                                  setSheetState(() {});
                                  setState(() => selectedCategory = name);
                                  Future.delayed(
                                      const Duration(milliseconds: 180), () {
                                    Navigator.pop(context);
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? color.withOpacity(0.22)
                                        : const Color(0xFF252540),
                                    borderRadius: BorderRadius.circular(50),
                                    border: Border.all(
                                      color: isSelected
                                          ? color
                                          : Colors.white.withOpacity(0.1),
                                      width: isSelected ? 1.8 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                      BoxShadow(
                                        color: color.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                        : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white.withOpacity(
                                                0.75),
                                            fontSize: 12.5,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildCategorySettingItem() {
    return InkWell(
      onTap: _showCategoryOptions,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B5C).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                color: Color(0xFFFF3B5C),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedCategory ?? 'Select category',
                    style: TextStyle(
                      fontSize: 12,
                      color: selectedCategory != null
                          ? const Color(0xFFFF3B5C)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  void _showCreateHashtagDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Create New Hashtag',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Enter hashtag (without #)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Only letters and numbers allowed',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final newHashtag = controller.text.trim();
                  if (newHashtag.isNotEmpty && newHashtag.length >= 2) {
                    final formattedHashtag = '#$newHashtag';

                    // Check if already exists
                    if (userHashtags.contains(formattedHashtag) ||
                        popularHashtags.contains(formattedHashtag)) {
                      _showSnackBar('Hashtag already exists');
                      return;
                    }

                    _addHashtagToDescription(formattedHashtag);
                    selectedHashtags.add(formattedHashtag);
                    _saveHashtagToFirestore(formattedHashtag);

                    Navigator.pop(context);
                    setState(() {
                      _showHashtagSuggestions = false;
                    });

                    _showSnackBar('Hashtag created: $formattedHashtag');
                  } else {
                    _showSnackBar('Hashtag must be at least 2 characters');
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? const Color(0xFF10B981) : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Error', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
              if (message.contains('Network') || message.contains('connection'))
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handlePostButtonClick();
                  },
                  child: const Text('Retry'),
                ),
            ],
          ),
    );
  }

  String _getHashtagDisplayInfo(String hashtag) {
    if (userHashtags.contains(hashtag)) {
      return 'Your hashtag';
    } else if (hashtagCounts.containsKey(hashtag)) {
      return hashtagCounts[hashtag]!;
    } else {
      return 'Popular';
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _scrollController.dispose();
    _videoController?.dispose();
    _hashtagSearchTimer?.cancel();
    _titleController.dispose();   // ✅ ADD THIS LINE

    VideoCompress.cancelCompression();
    super.dispose();
  }

  // 🎬 VIDEO DURATION CHECK & AUTO-TRIM
// 🎬 VIDEO DURATION CHECK & AUTO-TRIM
  Future<File?> _checkAndTrimVideo(File videoFile) async {
    try {
      debugPrint('🎬 Checking video duration...');

      // Video duration එක check කරන්න
      final controller = VideoPlayerController.file(videoFile);
      await controller.initialize();

      final duration = controller.value.duration;
      final durationInSeconds = duration.inSeconds;

      debugPrint('⏱️ Video duration: $durationInSeconds seconds');

      // Dispose කරන්න memory leak නොවෙන්න
      await controller.dispose();

      // ✅ තත්පර 60ට වැඩි නම් trim කරන්න (30 → 60 වෙනස් කළා)
      if (durationInSeconds > 60) {
        debugPrint('✂️ Video exceeds 60 seconds. Trimming required.');

        setState(() {
          _uploadProgress = 12;
          _uploadStatus = 'Video is ${durationInSeconds}s. Trimming to 60s...';
        });

        // ⚠️ Trimming fail වුණොත් null return කරනවා - upload එක නවත්තන්න
        return await _trimVideoTo60Seconds(videoFile);
      } else {
        debugPrint('✅ Video is within 60 seconds limit. No trimming needed.');
        return videoFile;
      }
    } catch (e) {
      debugPrint('❌ Error checking video duration: $e');
      return null;
    }
  }

  // ✂️ TRIM VIDEO TO 30 SECONDS
  // ✂️ TRIM VIDEO TO 60 SECONDS (30 → 60 වෙනස් කළා)
  Future<File?> _trimVideoTo60Seconds(File videoFile) async {
    try {
      debugPrint('✂️ Starting video trimming to 60 seconds...');

      setState(() {
        _uploadProgress = 13;
        _uploadStatus = 'Trimming video... Please wait';
      });

      // ✅ FIXED: Use compressVideo for trimming with 60 second duration
      final trimmedInfo = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
        startTime: 0,
        // Start at 0 seconds
        duration: 60,
        // ✅ 30 → 60 seconds (මෙතන විතරයි වෙනස)
        frameRate: 24,
      );

      if (trimmedInfo != null && trimmedInfo.file != null) {
        final originalSize = videoFile.lengthSync();
        final trimmedSize = trimmedInfo.filesize ?? 0;

        debugPrint('✅ Video trimmed successfully!');
        debugPrint('   Original: ${_formatFileSize(originalSize)}');
        debugPrint('   Trimmed: ${_formatFileSize(trimmedSize)} (60s)');
        debugPrint('   Duration: ${trimmedInfo.duration}s');

        setState(() {
          _uploadProgress = 14;
          _uploadStatus = 'Trimming complete! Video now 60 seconds.';
        });

        await Future.delayed(const Duration(milliseconds: 500));

        return trimmedInfo.file;
      } else {
        debugPrint('⚠️ Trimming returned null - Failed to trim');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Video trimming error: $e');
      return null;
    }
  }


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Auto-save draft on back
        final description = _descriptionController.text.trim();
        if (description.isNotEmpty) {
          await _saveToDrafts();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildMediaPreviewCard(),

                            const SizedBox(height: 20),
                            _buildDescriptionCard(),
                            const SizedBox(height: 16),
                            if (_showHashtagSuggestions) ...[
                              _buildHashtagSuggestionsCard(),
                              const SizedBox(height: 16),
                            ],
                            if (_showMentionSuggestions) ...[
                              _buildMentionSuggestionsCard(),
                              const SizedBox(height: 16),
                            ],
                            _buildActionButtons(),
                            if (mentionedUsers.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _buildMentionedUsersDisplay(),
                            ],
                            const SizedBox(height: 16),
                            _buildSettingsCard(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildBottomActionBar(),
                ],
              ),
              if (_showUploadDialog) _buildUploadProgressDialog(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          InkWell(
            onTap: () async {
              final description = _descriptionController.text.trim();
              if (description.isNotEmpty) {
                await _saveToDrafts();
              }
              if (mounted) {
                Navigator.pop(context);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Create Post',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildMediaPreviewCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal thumbnail strip
          _buildMediaThumbnailStrip(),
          const SizedBox(height: 12),
          // Ready to post + duration row
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Ready to post',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF10B981),
                ),
              ),
              if (_isVideo && _videoDuration != null) ...[
                const SizedBox(width: 12),
                Text(
                  'Duration: $_videoDuration',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
              if (_videoInfo != null) ...[
                const SizedBox(width: 8),
                Text(
                  _videoInfo!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaThumbnail() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_mediaFile != null)
              _isVideo
                  ? (_videoController?.value.isInitialized ?? false)
                  ? VideoPlayer(_videoController!)
                  : const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Image.file(_mediaFile!, fit: BoxFit.cover)
            else
              Container(
                color: Colors.grey[300],
                child: const Icon(Icons.image, size: 40, color: Colors.grey),
              ),
            if (_isVideo)
              Center(
                child: GestureDetector(
                  onTap: () {
                    if (_videoController?.value.isPlaying ?? false) {
                      _videoController?.pause();
                    } else {
                      _videoController?.play();
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isVideoPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    final remainingDesc = MAX_CHAR_LIMIT - _characterCount;
    final remainingTitle = MAX_TITLE_LIMIT - _titleCharCount;

    Color descCounterColor = remainingDesc < 0
        ? Colors.red
        : remainingDesc < 20 ? Colors.orange : Colors.grey;

    Color titleCounterColor = remainingTitle < 0
        ? Colors.red
        : remainingTitle < 10 ? Colors.orange : Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── TITLE FIELD (Image only) ──────────────────
          if (!_isVideo) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      maxLines: 1,
                      maxLength: MAX_TITLE_LIMIT,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Add a catchy title',
                        hintStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4A4A4A),
                        ),
                        border: InputBorder.none,
                        counterText: '',
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$remainingTitle',
                    style: TextStyle(
                      fontSize: 11,
                      color: titleCounterColor,
                    ),
                  ),
                ],
              ),
            ),

            // ── DIVIDER ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ],

          // ── DESCRIPTION FIELD ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _descriptionController,
              maxLines: 5,
              maxLength: MAX_CHAR_LIMIT,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
              decoration: const InputDecoration(
                hintText: "Writing a long description can help get 3x more views on average.",
                hintStyle: TextStyle(fontSize: 14, color: Color(0xFF4A4A4A)),
                border: InputBorder.none,
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // ── BOTTOM ROW (Mention + Char count) ────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    final currentText = _descriptionController.text;
                    final selection = _descriptionController.selection;
                    int cursorPosition = selection.baseOffset;
                    if (cursorPosition < 0) cursorPosition = currentText.length;

                    String textToInsert = '@';
                    if (currentText.isNotEmpty && cursorPosition > 0) {
                      final charBeforeCursor = currentText[cursorPosition - 1];
                      if (charBeforeCursor != ' ' && charBeforeCursor != '\n') {
                        textToInsert = ' @';
                      }
                    }

                    final beforeCursor = cursorPosition > 0
                        ? currentText.substring(0, cursorPosition) : '';
                    final afterCursor = cursorPosition < currentText.length
                        ? currentText.substring(cursorPosition) : '';

                    _descriptionController.text = beforeCursor + textToInsert + afterCursor;
                    _descriptionController.selection = TextSelection.fromPosition(
                      TextPosition(offset: beforeCursor.length + textToInsert.length),
                    );
                    setState(() => _showMentionSuggestions = true);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _showMentionSuggestions
                          ? const Color(0xFF3B82F6).withOpacity(0.2)
                          : const Color(0xFF3A3A3A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _showMentionSuggestions
                            ? const Color(0xFF3B82F6) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.alternate_email,
                          size: 16,
                          color: _showMentionSuggestions
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Mention',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _showMentionSuggestions
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$remainingDesc/$MAX_CHAR_LIMIT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: descCounterColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHashtagSuggestionsCard() {
    final hashtagsToShow = searchResults.isNotEmpty
        ? searchResults
        : [...userHashtags, ...popularHashtags].take(15).toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHashtagItem(
            hashtag: '+ Create New Hashtag',
            subtitle: '',
            isCreateOption: true,
            onTap: _showCreateHashtagDialog,
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.1)),
          ...hashtagsToShow.map(
                (hashtag) =>
                _buildHashtagItem(
                  hashtag: hashtag,
                  subtitle: _getHashtagDisplayInfo(hashtag),
                  onTap: () {
                    _insertHashtagAtCursor(hashtag);
                    if (!selectedHashtags.contains(hashtag)) {
                      selectedHashtags.add(hashtag);
                      _saveHashtagToFirestore(hashtag);
                    }
                    setState(() {
                      _showHashtagSuggestions = false;
                      searchResults.clear();
                      lastSearchQuery = "";
                    });
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHashtagItem({
    required String hashtag,
    required String subtitle,
    bool isCreateOption = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            if (!isCreateOption)
              Icon(
                userHashtags.contains(hashtag) ? Icons.star : Icons.tag,
                color: userHashtags.contains(hashtag)
                    ? Colors.amber
                    : const Color(0xFFFF3B5C),
                size: 20,
              )
            else
              Icon(Icons.add, color: Colors.grey.shade400, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hashtag,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isCreateOption
                          ? FontWeight.normal
                          : FontWeight.w600,
                      color: isCreateOption ? Colors.grey.shade400 : Colors
                          .white,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3), width: 1),
                ),
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showHashtagSuggestions = !_showHashtagSuggestions;
                      if (_showHashtagSuggestions) {
                        _addHashtagToDescription('#');
                      }
                    });
                  },
                  icon: const Icon(Icons.tag, size: 18),
                  label: Text(
                    _showHashtagSuggestions ? 'Hide hashtags' : 'Add hashtags',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3), width: 1),
                ),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TagFriendsScreen(),
                      ),
                    );

                    if (result != null && result is List) {
                      setState(() {
                        taggedFriends.clear();
                        for (var friend in result) {
                          taggedFriends.add({
                            'uid': friend.id,
                            'username': friend.name,
                            'avatarUrl': friend.avatarUrl,
                          });
                        }
                      });

                      if (taggedFriends.isNotEmpty) {
                        _showSnackBar(
                            '${taggedFriends.length} friend(s) tagged!',
                            isSuccess: true);
                      }
                    }
                  },
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: Text(
                    taggedFriends.isEmpty
                        ? 'Tag Friends'
                        : 'Friends (${taggedFriends.length})',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),

        if (taggedFriends.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildTaggedFriendsDisplay(),
        ],
      ],
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 👇 Category row - නව එක
          _buildCategorySettingItem(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
                height: 1, thickness: 1, color: Colors.white.withOpacity(0.1)),
          ),
          _buildSettingItem(
            icon: Icons.visibility_rounded,
            title: 'Who Can View',
            subtitle: selectedPrivacy,
            onTap: _showPrivacyOptions,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
                height: 1, thickness: 1, color: Colors.white.withOpacity(0.1)),
          ),
          _buildSettingItem(
            icon: Icons.tune_rounded,
            title: 'More Options',
            subtitle: 'Advanced settings',
            onTap: _showMoreOptions,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B5C).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.visibility_rounded,
                color: Color(0xFFFF3B5C),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
                Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: _isUploading
          ? const LinearProgressIndicator()
          : Row(
        children: [
          OutlinedButton(
            onPressed: _saveToDrafts,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            child: const Text(
              'Drafts',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _characterCount > MAX_CHAR_LIMIT
                  ? null
                  : _handlePostButtonClick,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B5C),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 2,
              ),
              child: const Text(
                'Post',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadProgressDialog() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Uploading...',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _showUploadDialog = false;
                      });
                      _showSnackBar('Upload cancelled');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isCompressing && _compressionStatus.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme
                                .of(context)
                                .primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _compressionStatus,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_mediaFile != null)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[200],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _isVideo
                        ? Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_videoController?.value.isInitialized ?? false)
                          VideoPlayer(_videoController!)
                        else
                          Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.videocam,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                        Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    )
                        : Image.file(_mediaFile!, fit: BoxFit.cover),
                  ),
                ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _uploadProgress / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme
                      .of(context)
                      .primaryColor,
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _uploadStatus,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_uploadProgress%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'File size:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '$_uploadedFileSize / $_totalFileSize',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ TAGGED FRIENDS DISPLAY WIDGET
  Widget _buildTaggedFriendsDisplay() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tagged Friends (${taggedFriends.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    taggedFriends.clear();
                  });
                  _showSnackBar('All tags removed');
                },
                child: const Text(
                    'Clear All', style: TextStyle(color: Color(0xFFFF3B5C))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: taggedFriends.map((friend) {
              return Chip(
                avatar: friend['avatarUrl']!.isNotEmpty
                    ? CircleAvatar(
                    backgroundImage: NetworkImage(friend['avatarUrl']!))
                    : CircleAvatar(
                  backgroundColor: const Color(0xFFFF3B5C),
                  child: Text(
                    friend['username']![0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                label: Text(friend['username']!),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => _removeTaggedFriend(friend['uid']!),
                backgroundColor: const Color(0xFFFF3B5C).withOpacity(0.2),
                labelStyle: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

// 🆕 @ MENTION DETECTION
  void _checkForMentionSearch(String text) {
    final cursorPosition = _descriptionController.selection.baseOffset;

    if (cursorPosition <= 0) {
      if (_showMentionSuggestions) {
        setState(() => _showMentionSuggestions = false);
      }
      return;
    }

    // @ character එක හොයන්න
    final atPosition = text.lastIndexOf('@', cursorPosition - 1);

    if (atPosition != -1) {
      // @ එක word එකක් ඇතුලේද check කරන්න
      final validStart = atPosition == 0 || text[atPosition - 1] == ' ';

      if (validStart) {
        String searchQuery = '';
        int endPosition = cursorPosition;

        // @ එකෙන් පස්සෙ තියෙන text එක අරගන්න
        for (int i = atPosition; i < text.length && i <= cursorPosition; i++) {
          if (text[i] == ' ') break;
          if (i == cursorPosition) {
            endPosition = i;
            break;
          }
        }

        if (endPosition > atPosition) {
          searchQuery = text.substring(atPosition + 1, endPosition);

          if (searchQuery.isNotEmpty && searchQuery != _lastMentionQuery) {
            _performMentionSearch(searchQuery);
            return;
          } else if (searchQuery.isEmpty) {
            setState(() => _showMentionSuggestions = true);
            return;
          }
        }
      }
    }

    // @ එකක් නැත්නම් suggestions hide කරන්න
    if (_showMentionSuggestions) {
      setState(() => _showMentionSuggestions = false);
    }
  }

// 🔍 USER SEARCH (FIRESTORE)
// 🔥 REPLACE කරන්න - Line 1095 ඇතුළත (දැනට තියෙන _performMentionSearch method එක)
  Future<void> _performMentionSearch(String query) async {
    if (_isMentionSearching || query == _lastMentionQuery) return;

    setState(() {
      _isMentionSearching = true;
      _lastMentionQuery = query;
      _mentionSearchResults.clear();
    });

    debugPrint('🔍 Searching users for: $query');

    try {
      final Set<String> addedUserIds = {};
      final List<Map<String, dynamic>> results = [];

      // 🎯 STEP 1: Mutual followers (දෙපැත්තෙන්ම follow කරන අය)
      final mutualFollowers = await _getMutualFollowers();

      if (query.isEmpty) {
        // Query එකක් නැත්නම් all mutual followers පෙන්වන්න
        for (var user in mutualFollowers) {
          if (!_isUserAlreadyMentioned(user['uid'])) {
            results.add(user);
            addedUserIds.add(user['uid']);
          }
        }
      } else {
        // Query එකක් තියෙනවනම් filter කරලා mutual followers පෙන්වන්න
        final searchQuery = query.toLowerCase();
        for (var user in mutualFollowers) {
          if (!_isUserAlreadyMentioned(user['uid']) &&
              (user['username'] as String).toLowerCase().contains(
                  searchQuery)) {
            results.add(user);
            addedUserIds.add(user['uid']);
          }
        }
      }

      // 🎯 STEP 2: Following list (මම follow කරන අනිත් අය - mutual නොවන අය)
      final followingList = await _getFollowingList();

      if (query.isEmpty) {
        // Query එකක් නැත්නම් following list පෙන්වන්න
        for (var user in followingList) {
          if (!addedUserIds.contains(user['uid']) &&
              !_isUserAlreadyMentioned(user['uid'])) {
            results.add(user);
            addedUserIds.add(user['uid']);
          }
        }
      } else {
        // Query එකක් තියෙනවනම් filter කරලා following list පෙන්වන්න
        final searchQuery = query.toLowerCase();
        for (var user in followingList) {
          if (!addedUserIds.contains(user['uid']) &&
              !_isUserAlreadyMentioned(user['uid']) &&
              (user['username'] as String).toLowerCase().contains(
                  searchQuery)) {
            results.add(user);
            addedUserIds.add(user['uid']);
          }
        }
      }

      // 🎯 STEP 3: Global search (query එකක් තියෙනවනම් විතරක්)
      if (query.isNotEmpty) {
        final searchQuery = query.toLowerCase();

        final querySnapshot = await _db
            .collection('users')
            .where('name', isGreaterThanOrEqualTo: searchQuery)
            .where('name', isLessThanOrEqualTo: '$searchQuery\uf8ff')
            .limit(20)
            .get();

        for (var doc in querySnapshot.docs) {
          if (!addedUserIds.contains(doc.id) &&
              !_isUserAlreadyMentioned(doc.id)) {
            final data = doc.data();
            results.add({
              'uid': doc.id,
              'username': data['name'] ?? 'Unknown',
              'avatarUrl': data['profileImageUrl'] ?? '',
              'isMutual': false,
            });
          }
        }
      }

      debugPrint('✅ Total users found: ${results.length}');
      debugPrint('   - Unique users: ${addedUserIds.length}');

      setState(() {
        _mentionSearchResults.clear();
        _mentionSearchResults.addAll(results);
      });
    } catch (e) {
      debugPrint('❌ Mention search error: $e');
    }

    setState(() {
      _isMentionSearching = false;
      _showMentionSuggestions =
          _mentionSearchResults.isNotEmpty || query.isEmpty;
    });
  }

  // 🆕 METHOD 1: Mutual followers ගන්න (දෙපැත්තෙන්ම follow කරන අය)
  Future<List<Map<String, dynamic>>> _getMutualFollowers() async {
    if (currentUserId == null) return []; // ✅ FIXED

    final mutualFollowers = <Map<String, dynamic>>[];

    try {
      debugPrint('🔍 Getting mutual followers...');

      // මම follow කරන අය ගන්න
      final myFollowingSnapshot = await _db
          .collection('follows')
          .where('followerId', isEqualTo: currentUserId) // ✅ FIXED
          .where('status', isEqualTo: 'active')
          .get();

      final myFollowingIds = myFollowingSnapshot.docs
          .map((doc) => doc.data()['followingId'] as String)
          .toList();

      debugPrint('👥 I follow ${myFollowingIds.length} people');

      // එක එක කෙනා මාව follow කරනවද බලන්න
      for (var followingId in myFollowingIds) {
        final theyFollowMeSnapshot = await _db
            .collection('follows')
            .where('followerId', isEqualTo: followingId)
            .where('followingId', isEqualTo: currentUserId) // ✅ FIXED
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();

        if (theyFollowMeSnapshot.docs.isNotEmpty) {
          // මේකයි mutual follower එකක්
          final userDoc = await _db.collection('users').doc(followingId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            mutualFollowers.add({
              'uid': followingId,
              'username': userData['name'] ?? 'Unknown',
              'avatarUrl': userData['profileImageUrl'] ?? '',
              'isMutual': true, // 🔥 IMPORTANT FLAG
            });
          }
        }
      }

      debugPrint('✅ Found ${mutualFollowers.length} mutual followers');
      return mutualFollowers;
    } catch (e) {
      debugPrint('❌ Error getting mutual followers: $e');
      return [];
    }
  }

// 🆕 METHOD 2: Following list ගන්න (මම follow කරන අනිත් අය)
// 🆕 METHOD 2: Following list ගන්න (මම follow කරන අනිත් අය)
// 🔧 FIXED: _currentUserId → currentUserId
  Future<List<Map<String, dynamic>>> _getFollowingList() async {
    if (currentUserId == null) return []; // ✅ FIXED

    final followingList = <Map<String, dynamic>>[];

    try {
      debugPrint('🔍 Getting following list...');

      final followingSnapshot = await _db
          .collection('follows')
          .where('followerId', isEqualTo: currentUserId) // ✅ FIXED
          .where('status', isEqualTo: 'active')
          .get();

      for (var doc in followingSnapshot.docs) {
        final followingId = doc.data()['followingId'] as String;

        final userDoc = await _db.collection('users').doc(followingId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          followingList.add({
            'uid': followingId,
            'username': userData['name'] ?? 'Unknown',
            'avatarUrl': userData['profileImageUrl'] ?? '',
            'isMutual': false, // 🔥 IMPORTANT FLAG
          });
        }
      }

      debugPrint('✅ Found ${followingList.length} following');
      return followingList;
    } catch (e) {
      debugPrint('❌ Error getting following list: $e');
      return [];
    }
  }

// ✅ USER SELECT කරන්න
  void _insertMentionAtCursor(Map<String, dynamic> user) {
    final currentText = _descriptionController.text;
    final cursorPosition = _descriptionController.selection.baseOffset;
    final atPosition = currentText.lastIndexOf('@', cursorPosition - 1);

    if (atPosition != -1) {
      final beforeAt = currentText.substring(0, atPosition);
      final afterCursor = currentText.substring(cursorPosition);
      final mention = '@${user['username']}';
      final newText = '$beforeAt$mention $afterCursor';

      _descriptionController.text = newText;
      _descriptionController.selection = TextSelection.fromPosition(
        TextPosition(offset: atPosition + mention.length + 1),
      );

      // Mentioned users list එකට add කරන්න
      if (!mentionedUsers.any((u) => u['uid'] == user['uid'])) {
        mentionedUsers.add({
          'uid': user['uid']!,
          'username': user['username']!,
          'avatarUrl': user['avatarUrl'] ?? '',
        });
        debugPrint('✅ Mentioned: ${user['username']}');
      }
    }

    setState(() {
      _showMentionSuggestions = false;
      _mentionSearchResults.clear();
      _lastMentionQuery = '';
    });
  }

  Widget _buildMentionSuggestionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 300), // 🆕 Height limit
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                    Icons.alternate_email, color: Color(0xFF3B82F6), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Mention Friends',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (_isMentionSearching)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF3B82F6),
                    ),
                  )
                else
                  if (_lastMentionQuery.isNotEmpty)
                    Text(
                      'Results for "@$_lastMentionQuery"',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.white.withOpacity(0.1)),

          // Results list (scrollable if needed)
          if (_mentionSearchResults.isEmpty && !_isMentionSearching)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.person_search,
                    size: 48,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lastMentionQuery.isEmpty
                        ? 'Type to search friends...'
                        : 'No users found matching "@$_lastMentionQuery"',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _mentionSearchResults.length,
                itemBuilder: (context, index) {
                  return _buildMentionItem(_mentionSearchResults[index]);
                },
              ),
            ),
        ],
      ),
    );
  }

// 🆕 SINGLE MENTION ITEM
// 🔥 REPLACE කරන්න - _buildMentionItem() method එක (mutual badge එක පෙන්වන්න)
  Widget _buildMentionItem(Map<String, dynamic> user) {
    final isAlreadyMentioned = mentionedUsers.any((u) =>
    u['uid'] == user['uid']);
    final isMutual = user['isMutual'] ?? false; // 🆕 Mutual check කරන්න

    return InkWell(
      onTap: isAlreadyMentioned ? null : () => _insertMentionAtCursor(user),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isAlreadyMentioned
              ? Colors.grey.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: user['avatarUrl'] != null &&
                      user['avatarUrl'].isNotEmpty
                      ? Image.network(
                    user['avatarUrl'],
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultAvatar(user['username']);
                    },
                  )
                      : _buildDefaultAvatar(user['username']),
                ),

                // 🆕 Mutual badge (mutual follower නම් පෙන්වන්න)
                if (isMutual && !isAlreadyMentioned)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF2A2A2A), width: 2),
                      ),
                      child: const Icon(
                        Icons.people,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),

                // Already mentioned badge
                if (isAlreadyMentioned)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF2A2A2A), width: 2),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Username
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user['username'],
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isAlreadyMentioned
                                ? Colors.grey[600]
                                : Colors.white,
                            decoration: isAlreadyMentioned
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // 🆕 Mutual follower badge (text)
                      if (isMutual && !isAlreadyMentioned) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Mutual',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  if (isAlreadyMentioned)
                    const Text(
                      'Already mentioned',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                ],
              ),
            ),

            // Icon
            Icon(
              isAlreadyMentioned ? Icons.check_circle : Icons.alternate_email,
              color: isAlreadyMentioned
                  ? const Color(0xFF10B981)
                  : const Color(0xFF3B82F6),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

// 🆕 MENTIONED USERS DISPLAY
  Widget _buildMentionedUsersDisplay() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.alternate_email,
                      color: Color(0xFF3B82F6),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Mentioned (${mentionedUsers.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    mentionedUsers.clear();
                  });
                  _showSnackBar('All mentions removed', isSuccess: true);
                },
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: Color(0xFF3B82F6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: mentionedUsers.map((user) {
              return Chip(
                avatar: user['avatarUrl']!.isNotEmpty
                    ? CircleAvatar(
                  backgroundImage: NetworkImage(user['avatarUrl']!),
                )
                    : CircleAvatar(
                  backgroundColor: const Color(0xFF3B82F6),
                  child: Text(
                    user['username']![0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                label: Text('@${user['username']!}'),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() {
                    mentionedUsers.removeWhere((u) => u['uid'] == user['uid']);
                  });
                  _showSnackBar('Mention removed', isSuccess: true);
                },
                backgroundColor: const Color(0xFF3B82F6).withOpacity(0.2),
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 🆕 DEFAULT AVATAR (when no profile pic)
  Widget _buildDefaultAvatar(String username) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFFFF3B5C),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

// ── Multi-media thumbnail strip (horizontal) ────────────────────
// Images 3ක් ආවොත් 3ම පෙන්වනවා, නැත්නම් + button ත් පෙන්වනවා
  Widget _buildMediaThumbnailStrip() {

    // ✅ මෙහෙම කරන්න (_localMediaPaths - mutable, setState එකෙන් update වෙනවා)
    final paths = _localMediaPaths.isNotEmpty
        ? _localMediaPaths
        : [widget.mediaFile.path];
    final isVideos = _localMediaIsVideo.isNotEmpty
        ? _localMediaIsVideo
        : [widget.isVideo];

    // State manage කරන්න - mutable list එකක් ඕන
    // Note: widget params direct modify කරන්න බැහැ,
    // ඒ නිසා _localMediaPaths සහ _localMediaIsVideo use කරන්න

    final canAddMore = !isVideos.contains(true) && paths.length < 3;
    final itemCount = paths.length + (canAddMore ? 1 : 0);

    return SizedBox(
      height: 110, // close button සඳහා 100 → 110
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Add more (+) button
          if (index == paths.length) {
            return GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 100,
                height: 100,
                margin: const EdgeInsets.only(right: 8, top: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Colors.white54, size: 32),
                    SizedBox(height: 4),
                    Text('Add',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            );
          }

          final path = paths[index];
          final isVid = isVideos.length > index ? isVideos[index] : false;
          // Primary image (index==0) delete කරන්න බෑ
          final canDelete = index > 0;

          return SizedBox(
            width: 108,
            height: 110,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Thumbnail
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      // ✅ මෙහෙම කරන්න
                      border: Border.all(
                        color: Colors.white12,
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // ── Base media ─────────────────────────────────
                          if (isVid && index == 0 && (_videoController?.value.isInitialized ?? false))
                            ColorFiltered(
                              colorFilter: ColorFilter.matrix(
                                widget.activeFilterMatrix ?? [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0],
                              ),
                              child: VideoPlayer(_videoController!),
                            )
                          else if (isVid)
                            Container(
                              color: const Color(0xFF1A1A1A),
                              child: const Center(
                                child: Icon(Icons.videocam, color: Colors.white38, size: 32),
                              ),
                            )
                          else
                            ColorFiltered(
                              colorFilter: ColorFilter.matrix(
                                widget.activeFilterMatrix ?? [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0],
                              ),
                              child: Image.file(File(path), fit: BoxFit.cover),
                            ),

                          // ── Effects overlay (index==0 විතරක්) ──────────
                          if (index == 0)
                            ...widget.effectLayers.map((layer) =>
                                Positioned.fill(
                                  child: buildEffectOverlay(layer.effectKey, layer.intensity),
                                ),
                            ),

                          // ── Stickers (index==0 විතරක්, thumbnail scale කරලා) ──
                          if (index == 0)
                            ...widget.placedStickers.map((s) {
                              final scale = (s['scale'] as double).clamp(0.1, 4.0);
                              return Positioned(
                                left: ((s['x'] as double) / MediaQuery.of(context).size.width * 100).clamp(0, 80),
                                top: ((s['y'] as double) / MediaQuery.of(context).size.height * 100).clamp(0, 80),
                                child: Transform.rotate(
                                  angle: s['angle'] as double,
                                  child: Text(
                                    s['emoji'] as String,
                                    style: TextStyle(fontSize: 12 * scale),
                                  ),
                                ),
                              );
                            }),

                          // ── Edit badge (effects/filters/stickers දාලා නම්) ──
                          if (index == 0 && (widget.effectLayers.isNotEmpty ||
                              widget.activeFilterMatrix != null ||
                              widget.placedStickers.isNotEmpty ||
                              widget.textOverlays.isNotEmpty))
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_fix_high, color: Colors.white, size: 10),
                                    SizedBox(width: 3),
                                    Text('Edited', style: TextStyle(color: Colors.white, fontSize: 9)),
                                  ],
                                ),
                              ),
                            ),

                          // ── Video play icon ────────────────────────────
                          if (isVid)
                            Container(
                              color: Colors.black26,
                              child: const Center(
                                child: Icon(Icons.play_arrow, color: Colors.white, size: 28),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),


                // Close button (primary image වලට නෑ)
                if (canDelete)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          // allMediaPaths/allMediaIsVideo widget params නිසා
                          // direct modify කරන්න බෑ - snackbar පෙන්වන්න
                          // TODO: parent state manage කරනවා නම් callback use කරන්න
                        });
                        _removeMediaAtIndex(index);
                      },
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white54, width: 1),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _removeMediaAtIndex(int index) {
    if (index <= 0 || index >= _localMediaPaths.length) return;
    setState(() {
      _localMediaPaths.removeAt(index);
      _localMediaIsVideo.removeAt(index);
    });
    _showSnackBar('Image removed', isSuccess: true);
  }
}