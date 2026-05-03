import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:my_vibe_flick/screens/upload_screen.dart';
import 'package:video_player/video_player.dart';

// ============================================================
// 🎵 ROTATING VINYL DISC WIDGET
// ============================================================

class RotatingVinylDisc extends StatefulWidget {
  final bool isPlaying;
  final String? albumArtUrl;
  final VoidCallback onTap;
  final String heroTag;
  final String? soundId; // 🆕 ADD THIS LINE

  const RotatingVinylDisc({
    Key? key,
    required this.isPlaying,
    this.albumArtUrl,
    required this.onTap,
    this.heroTag = 'vinyl_disc',
    this.soundId, // 🆕 ADD THIS LINE
  }) : super(key: key);

  @override
  State<RotatingVinylDisc> createState() => _RotatingVinylDiscState();
}

class _RotatingVinylDiscState extends State<RotatingVinylDisc>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _particleController;

  final List<MusicParticle> _particles = [];

  // 🆕 Image post album art support
  String? _loadedAlbumArtUrl;
  bool _isLoadingArt = false;

  @override
  void initState() {
    super.initState();
// 🆕 Load album art for image posts
    _loadAlbumArtIfNeeded();

    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _initializeParticles();

    if (widget.isPlaying) {
      _rotationController.repeat();
      _particleController.repeat();
    }

    _particleController.addStatusListener((status) {
      if (status == AnimationStatus.completed && widget.isPlaying) {
        setState(() {
          _initializeParticles();
        });
      }
    });
  }

  void _initializeParticles() {
    _particles.clear();
    final random = math.Random();
    for (int i = 0; i < 3; i++) {
      _particles.add(MusicParticle(
        startX: -10 + random.nextDouble() * 20,
        startY: 0,
        endY: -40 - random.nextDouble() * 20,
        delay: i * 0.3,
        opacity: 0.6 + random.nextDouble() * 0.4,
      ));
    }
  }

  @override
  void didUpdateWidget(RotatingVinylDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 🆕 Reload art if soundId changed
    if (widget.soundId != oldWidget.soundId ||
        widget.albumArtUrl != oldWidget.albumArtUrl) {
      _loadAlbumArtIfNeeded();
    }
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
        _particleController.repeat();
      } else {
        _rotationController.stop();
        _particleController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (widget.isPlaying)
              ..._particles.map((particle) => _buildParticle(particle)),

            Hero(
              tag: widget.heroTag,
              child: AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationController.value * 2 * math.pi,
                    child: child,
                  );
                },
                child: Container(
                  width: 47,
                  height: 47,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    // 🆕 _loadedAlbumArtUrl use කරනවා (video + image posts දෙකටම)
                    child: _loadedAlbumArtUrl != null &&
                        _loadedAlbumArtUrl!.isNotEmpty
                        ? Image.network(
                      _loadedAlbumArtUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultVinylIcon();
                      },
                    )
                        : _buildDefaultVinylIcon(),
                  ),
                ),
              ),
            ),

            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultVinylIcon() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Icon(Icons.music_note, color: Colors.white54, size: 24),
    );
  }

  Widget _buildParticle(MusicParticle particle) {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        double progress =
        (_particleController.value - particle.delay).clamp(0.0, 1.0);
        double opacity = particle.opacity * (1 - progress);
        double x = particle.startX;
        double y = particle.startY +
            (particle.endY - particle.startY) * progress;

        return Positioned(
          left: 30 + x,
          bottom: 30 + y,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.8 + progress * 0.4,
              child: const Icon(
                Icons.music_note,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        );
      },
    );
  }
  // 🆕 NEW METHOD: Image post සඳහා album art load කිරීම
  // soundId දී ඇත්නම් Firestore වලින් thumbnail_url ගන්නවා
  Future<void> _loadAlbumArtIfNeeded() async {
    // widget.albumArtUrl already ඇත්නම් use කරනවා
    if (widget.albumArtUrl != null && widget.albumArtUrl!.isNotEmpty) {
      if (mounted) setState(() => _loadedAlbumArtUrl = widget.albumArtUrl);
      return;
    }

    // soundId නැත්නම් skip
    if (widget.soundId == null || widget.soundId!.isEmpty) return;

    if (_isLoadingArt) return;
    if (mounted) setState(() => _isLoadingArt = true);

    try {
      // audio_id match වන posts වලින් ඉස්සෙල්ලාම uploaded post එකේ thumbnail ගන්නවා
      final snapshot = await FirebaseFirestore.instance
          .collection('media_posts')
          .where('audio_id', isEqualTo: widget.soundId)
          .orderBy('timestamp', descending: false) // oldest first = original creator
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty && mounted) {
        final data = snapshot.docs.first.data();
        // Video post නම් thumbnail_url, image post නම් media_urls[0] ගන්නවා
        String? artUrl = data['thumbnail_url'] as String?;
        if (artUrl == null || artUrl.isEmpty) {
          final mediaUrls = data['media_urls'];
          if (mediaUrls is List && mediaUrls.isNotEmpty) {
            artUrl = mediaUrls[0] as String?;
          }
        }
        if (mounted) setState(() => _loadedAlbumArtUrl = artUrl);
      }
    } catch (e) {
      debugPrint('⚠️ Album art load error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingArt = false);
    }
  }


}


class MusicParticle {
  final double startX;
  final double startY;
  final double endY;
  final double delay;
  final double opacity;

  MusicParticle({
    required this.startX,
    required this.startY,
    required this.endY,
    required this.delay,
    required this.opacity,
  });
}

// ============================================================
// 🎵 SOUND DETAIL PAGE
// ============================================================

class SoundDetailPage extends StatefulWidget {
  final String soundId;
  final String soundName;
  final String? albumArtUrl;
  final String heroTag;
  final String creatorUsername;
  final String? creatorProfileUrl;
  final String? soundUrl;

  const SoundDetailPage({
    Key? key,
    required this.soundId,
    required this.soundName,
    this.albumArtUrl,
    required this.heroTag,
    required this.creatorUsername,
    this.creatorProfileUrl,
    this.soundUrl,
  }) : super(key: key);

  @override
  State<SoundDetailPage> createState() => _SoundDetailPageState();
}

class _SoundDetailPageState extends State<SoundDetailPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late AnimationController _vinylRotationController;
  late AnimationController _waveController;
  late AnimationController _particleController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isFavorited = false;
  bool _isLoadingFavorite = false;
  List<Map<String, dynamic>> _soundVideos = [];
  bool _isLoadingVideos = true;
  String? _currentUserId;
  int _usageCount = 0;

  final List<double> _waveHeights =
  List.generate(20, (i) => 0.3 + math.Random().nextDouble() * 0.7);

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;

    _vinylRotationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _particleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _fadeController.forward();
    _loadSoundVideos();
    _checkFavoriteStatus();
  }

  @override
  void dispose() {
    _vinylRotationController.dispose();
    _waveController.dispose();
    _particleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
  Future<void> _loadSoundVideos() async {
    try {
      setState(() => _isLoadingVideos = true);

      debugPrint('🔍 Loading sound videos for audio_id: ${widget.soundId}');

      // ✅ FIX: audio_id විතරක් filter කරනවා
      // username filter නෑ — ඕනෑම user කෙනෙක් මේ sound use කළ videos පෙන්වෙනවා
      QuerySnapshot snapshot = await _db
          .collection('media_posts')
          .where('audio_id', isEqualTo: widget.soundId)
          .get();

      debugPrint('📊 Videos found by audio_id: ${snapshot.docs.length}');

      // Fallback: audio_id නැත්නම් audio_name වලින් හොයන්න
      if (snapshot.docs.isEmpty) {
        debugPrint('⚠️ No results by audio_id, trying audio_name...');
        snapshot = await _db
            .collection('media_posts')
            .where('audio_name', isEqualTo: widget.soundName)
            .get();
        debugPrint('📊 Videos found by audio_name: ${snapshot.docs.length}');
      }

      final videos = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      // Newest first sort
      videos.sort((a, b) {
        int aTime = 0, bTime = 0;
        final aRaw = a['timestamp'];
        final bRaw = b['timestamp'];
        if (aRaw is int) aTime = aRaw;
        else if (aRaw != null) {
          try { aTime = (aRaw as Timestamp).millisecondsSinceEpoch; } catch (_) {}
        }
        if (bRaw is int) bTime = bRaw;
        else if (bRaw != null) {
          try { bTime = (bRaw as Timestamp).millisecondsSinceEpoch; } catch (_) {}
        }
        return bTime.compareTo(aTime);
      });

      setState(() {
        _soundVideos = videos;
        _usageCount = videos.length;
        _isLoadingVideos = false;
      });

      debugPrint('✅ Final video count: ${videos.length}');
      final uniqueUsers = videos.map((v) => v['username']).toSet();
      debugPrint('👥 From ${uniqueUsers.length} users: $uniqueUsers');

    } catch (e) {
      debugPrint('❌ Error loading sound videos: $e');
      setState(() => _isLoadingVideos = false);
    }
  }

  Future<void> _checkFavoriteStatus() async {
    if (_currentUserId == null) return;
    try {
      final doc = await _db
          .collection('users')
          .doc(_currentUserId)
          .collection('favorite_sounds')
          .doc(widget.soundId)
          .get();
      setState(() => _isFavorited = doc.exists);
    } catch (e) {
      debugPrint('❌ Error checking favorite: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentUserId == null) return;
    if (_isLoadingFavorite) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoadingFavorite = true);

    try {
      final ref = _db
          .collection('users')
          .doc(_currentUserId)
          .collection('favorite_sounds')
          .doc(widget.soundId);

      if (_isFavorited) {
        await ref.delete();
        setState(() => _isFavorited = false);
        _showToast('Removed from favorites');
      } else {
        await ref.set({
          'soundId': widget.soundId,
          'soundName': widget.soundName,
          'albumArtUrl': widget.albumArtUrl ?? '',
          'creatorUsername': widget.creatorUsername,
          'soundUrl': widget.soundUrl ?? '',
          'savedAt': DateTime.now().millisecondsSinceEpoch,
        });
        setState(() => _isFavorited = true);
        _showToast('Added to favorites ❤️');
      }
    } catch (e) {
      debugPrint('❌ Error toggling favorite: $e');
    } finally {
      setState(() => _isLoadingFavorite = false);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A2E),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _useThisSound() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UploadScreen(
          preselectedSoundId: widget.soundId,
          preselectedSoundName: widget.soundName,
          preselectedSoundUrl: widget.soundUrl,
          preselectedSoundAlbumArt: widget.albumArtUrl,
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            _buildBackground(),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildSoundHero(),
                  _buildSoundInfo(),
                  const SizedBox(height: 16),
                  _buildVideosGrid(),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, _) {
        return CustomPaint(
          painter: _BackgroundPainter(
            progress: _particleController.value,
            accentColor: const Color(0xFFFF3B5C),
          ),
          child: Container(),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 18),
            ),
          ),
          const Spacer(),
          const Text(
            'Sound',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _toggleFavorite,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isFavorited
                    ? const Color(0xFFFF3B5C).withOpacity(0.2)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isFavorited
                      ? const Color(0xFFFF3B5C).withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Icon(
                _isFavorited ? Icons.bookmark : Icons.bookmark_border,
                color:
                _isFavorited ? const Color(0xFFFF3B5C) : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundHero() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ...[80.0, 70.0, 60.0].asMap().entries.map((entry) {
                return AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) {
                    final pulse = 1.0 +
                        (_waveController.value * 0.08 * (entry.key + 1));
                    return Container(
                      width: entry.value * pulse,
                      height: entry.value * pulse,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFF3B5C)
                              .withOpacity(0.15 - entry.key * 0.04),
                          width: 1,
                        ),
                      ),
                    );
                  },
                );
              }),

              // 🎯 Hero animation - rotating vinyl disc
              Hero(
                tag: widget.heroTag,
                child: AnimatedBuilder(
                  animation: _vinylRotationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle:
                      _vinylRotationController.value * 2 * math.pi,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A1A2E),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3B5C).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: widget.albumArtUrl != null &&
                          widget.albumArtUrl!.isNotEmpty
                          ? Image.network(
                        widget.albumArtUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildDefaultVinyl(),
                      )
                          : _buildDefaultVinyl(),
                    ),
                  ),
                ),
              ),

              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0A0A0F),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3), width: 1.5),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _buildSoundWave(),
        ],
      ),
    );
  }

  Widget _buildDefaultVinyl() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Icon(Icons.music_note, color: Colors.white54, size: 44),
    );
  }

  Widget _buildSoundWave() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        return SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_waveHeights.length, (i) {
              final animated = _waveHeights[i] *
                  (0.4 +
                      0.6 *
                          math
                              .sin(_waveController.value * math.pi +
                              i * 0.4)
                              .abs());
              return Container(
                width: 3,
                height: 8 + animated * 30,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B5C)
                      .withOpacity(0.5 + animated * 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildSoundInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            widget.soundName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_outline,
                  color: Color(0xFFAAAAAA), size: 14),
              const SizedBox(width: 4),
              Text(
                widget.creatorUsername,
                style: const TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B5C).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFF3B5C).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_circle_outline,
                    color: Color(0xFFFF3B5C), size: 16),
                const SizedBox(width: 6),
                Text(
                  '${_formatCount(_usageCount)} videos',
                  style: const TextStyle(
                    color: Color(0xFFFF3B5C),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideosGrid() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B5C),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Videos using this sound',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingVideos
                ? _buildLoadingGrid()
                : _soundVideos.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
                childAspectRatio: 9 / 16,
              ),
              itemCount: _soundVideos.length,
              itemBuilder: (context, index) {
                return _buildVideoThumbnail(
                    _soundVideos[index], index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoThumbnail(Map<String, dynamic> post, int index) {
    final thumbnailUrl = post['thumbnail_url'] as String?;
    final likes = post['likes'] as int? ?? 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showVideoPreview(post);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            thumbnailUrl != null && thumbnailUrl.isNotEmpty
                ? Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF1A1A2E),
                child: const Icon(Icons.videocam,
                    color: Colors.white30, size: 30),
              ),
            )
                : Container(
              color: const Color(0xFF1A1A2E),
              child: const Icon(Icons.videocam,
                  color: Colors.white30, size: 30),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            const Center(
              child: Icon(Icons.play_arrow_rounded,
                  color: Colors.white54, size: 28),
            ),
            Positioned(
              bottom: 5,
              left: 5,
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 10),
                  const SizedBox(width: 3),
                  Text(
                    _formatCount(likes),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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

  void _showVideoPreview(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _VideoPreviewSheet(
        mediaUrl: post['media_url'] as String? ?? '',
        username: post['username'] ?? 'Unknown',
        description: post['description'] ?? '',
        thumbnailUrl: post['thumbnail_url'],
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        childAspectRatio: 9 / 16,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: _ShimmerBox(),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off_outlined,
              size: 60, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 12),
          Text(
            'No videos with this sound yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Be the first to use it!',
            style: TextStyle(
              color: const Color(0xFFFF3B5C).withOpacity(0.6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A0A0F).withOpacity(0.0),
            const Color(0xFF0A0A0F).withOpacity(0.95),
            const Color(0xFF0A0A0F),
          ],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleFavorite,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _isFavorited
                    ? const Color(0xFFFF3B5C).withOpacity(0.15)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isFavorited
                      ? const Color(0xFFFF3B5C).withOpacity(0.5)
                      : Colors.white.withOpacity(0.15),
                ),
              ),
              child: Icon(
                _isFavorited ? Icons.bookmark : Icons.bookmark_border,
                color: _isFavorited
                    ? const Color(0xFFFF3B5C)
                    : Colors.white70,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _useThisSound,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3B5C), Color(0xFFFF6B35)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3B5C).withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_rounded,
                        color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Use this Sound',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
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
  }
}

// ============================================================
// 🎬 VIDEO PREVIEW BOTTOM SHEET
// ============================================================

class _VideoPreviewSheet extends StatefulWidget {
  final String mediaUrl;
  final String username;
  final String description;
  final String? thumbnailUrl;

  const _VideoPreviewSheet({
    required this.mediaUrl,
    required this.username,
    required this.description,
    this.thumbnailUrl,
  });

  @override
  State<_VideoPreviewSheet> createState() => _VideoPreviewSheetState();
}

class _VideoPreviewSheetState extends State<_VideoPreviewSheet> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl));
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.play();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('❌ Video preview error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
            child: _isInitialized && _controller != null
                ? Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: VideoPlayer(_controller!),
              ),
            )
                : widget.thumbnailUrl != null
                ? Image.network(widget.thumbnailUrl!,
                fit: BoxFit.cover, width: double.infinity)
                : Container(
              color: const Color(0xFF1A1A2E),
              child: const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFFF3B5C)),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                  stops: [0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${widget.username}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (widget.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      widget.description,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 🎨 BACKGROUND PAINTER
// ============================================================

class _BackgroundPainter extends CustomPainter {
  final double progress;
  final Color accentColor;

  _BackgroundPainter({required this.progress, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0A0A0F),
    );

    final orb1Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withOpacity(0.08 + progress * 0.04),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.85, size.height * 0.1),
          radius: 180,
        ),
      );

    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.1),
      180,
      orb1Paint,
    );

    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.fill;

    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => old.progress != progress;
}

// ============================================================
// ⬜ SHIMMER LOADING BOX
// ============================================================

class _ShimmerBox extends StatefulWidget {
  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Color.lerp(
              const Color(0xFF1A1A2E), const Color(0xFF2A2A3E), _anim.value),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}