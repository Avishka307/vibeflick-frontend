import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math' as math;
import 'package:shimmer/shimmer.dart';

/// 🎵 Enhanced Sound Detail Page with Hero Animation
/// Shows all videos that use the same audio/sound
class SoundDetailPage extends StatefulWidget {
  final String soundId;
  final String soundName;
  final String? albumArtUrl;
  final String heroTag;
  final String? creatorUsername;
  final String? creatorProfileUrl;
  final String? soundUrl; // URL to the actual audio file

  const SoundDetailPage({
    Key? key,
    required this.soundId,
    required this.soundName,
    this.albumArtUrl,
    this.heroTag = 'vinyl_disc',
    this.creatorUsername,
    this.creatorProfileUrl,
    this.soundUrl,
  }) : super(key: key);

  @override
  State<SoundDetailPage> createState() => _SoundDetailPageState();
}

class _SoundDetailPageState extends State<SoundDetailPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _videosWithThisSound = [];
  bool _isLoading = true;
  int _totalVideos = 0;
  bool _isFavorited = false;
  bool _isPlayingSound = false;

  // 🆕 Pagination variables
  static const int _pageSize = 6;
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  DocumentSnapshot? _lastDocument;
  final ScrollController _scrollController = ScrollController();

  // 🆕 Sound creator profile variables
  String? _creatorUid;
  String? _resolvedCreatorUsername;
  String? _resolvedCreatorProfileUrl;
  bool _isLoadingCreator = true;

  late AnimationController _pulseController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadVideosWithSound();
    _checkIfFavorited();
// 🆕 Load sound creator profile
    _loadSoundCreatorProfile();
    // 🆕 Pagination scroll listener
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreVideos();
      }
    });
    // Pulse animation for the album art
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )
      ..repeat(reverse: true);

    // Listen to audio player state
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingSound = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingSound = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer.dispose();
    // 🆕 Dispose scroll controller
    _scrollController.dispose();
    super.dispose();
  }

// ============================================================
  // 🆕 NEW METHOD: Sound creator profile load කිරීම
  // ඉස්සෙල්ලාම sound use කළ user (oldest post) profile ගන්නවා
  // ============================================================
  Future<void> _loadSoundCreatorProfile() async {
    if (mounted) setState(() => _isLoadingCreator = true);
    try {
      // widget.creatorUsername already pass වී ඇත්නම් use කරනවා
      // නමුත් profile image Firestore වලින් ගන්නවා
      String? targetUsername = widget.creatorUsername;

      // soundId දී ඇත්නම් oldest post ගෙන original creator හොයනවා
      if (widget.soundId.isNotEmpty && widget.soundId != 'original_sound') {
        final snapshot = await _db
            .collection('media_posts')
            .where('audio_id', isEqualTo: widget.soundId)
            .orderBy(
            'timestamp', descending: false) // oldest = original creator
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          final uid = data['uid'] as String?;
          _creatorUid = uid;
          targetUsername =
              data['username'] as String? ?? widget.creatorUsername;

          // Firestore users collection වලින් profile data ගන්නවා
          if (uid != null && uid.isNotEmpty) {
            final userDoc = await _db.collection('users').doc(uid).get();
            if (userDoc.exists && mounted) {
              final userData = userDoc.data()!;
              setState(() {
                _resolvedCreatorUsername =
                    userData['name'] as String? ?? targetUsername;
                _resolvedCreatorProfileUrl =
                    userData['profile_picture_url'] as String? ??
                        userData['profile_url'] as String? ??
                        userData['profileUrl'] as String?;
              });
            }
          }
        }
      }

      // Fallback: widget params use කරනවා
      if (_resolvedCreatorUsername == null && mounted) {
        setState(() {
          _resolvedCreatorUsername = widget.creatorUsername ?? 'Original Sound';
          _resolvedCreatorProfileUrl = widget.creatorProfileUrl;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Creator profile load error: $e');
      if (mounted) setState(() {
        _resolvedCreatorUsername = widget.creatorUsername ?? 'Original Sound';
        _resolvedCreatorProfileUrl = widget.creatorProfileUrl;
      });
    } finally {
      if (mounted) setState(() => _isLoadingCreator = false);
    }
  }

  // ============================================================
  // 🆕 NEW METHOD: Load more videos (pagination - 6 by 6)
  // ============================================================
  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasMorePosts) return;
    if (mounted) setState(() => _isLoadingMore = true);

    try {
      Query query = _db
          .collection('media_posts')
          .where('audio_id', isEqualTo: widget.soundId)
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        if (mounted) setState(() => _hasMorePosts = false);
        return;
      }

      _lastDocument = snapshot.docs.last;

      final newVideos = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'uid': data['uid'] ?? '',
          'username': data['username'] ?? 'Unknown',
          'media_url': data['media_url'] ?? '',
          'thumbnail_url': data['thumbnail_url'] ?? '',
          'type': data['type'] ?? 'video',
          'description': data['description'] ?? '',
          'timestamp': data['timestamp'],
          'likes': data['likes'] ?? 0,
          'views': data['views'] ?? data['viewCount'] ?? 0,
        };
      }).toList();

      if (mounted) setState(() {
        _videosWithThisSound.addAll(newVideos);
        _hasMorePosts = snapshot.docs.length >= _pageSize;
        _isLoadingMore = false;
      });

      debugPrint('📄 Loaded ${newVideos
          .length} more videos (total: ${_videosWithThisSound.length})');
    } catch (e) {
      debugPrint('❌ Load more error: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _checkIfFavorited() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final favDoc = await _db
          .collection('users')
          .doc(userId)
          .collection('favorite_sounds')
          .doc(widget.soundId)
          .get();

      if (mounted) {
        setState(() {
          _isFavorited = favDoc.exists;
        });
      }
    } catch (e) {
      debugPrint('❌ Error checking favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to save sounds'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final favRef = _db
          .collection('users')
          .doc(userId)
          .collection('favorite_sounds')
          .doc(widget.soundId);

      if (_isFavorited) {
        await favRef.delete();
        setState(() {
          _isFavorited = false;
        });
        debugPrint('💔 Removed from favorites: ${widget.soundId}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from favorites'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        await favRef.set({
          'soundId': widget.soundId,
          'soundName': widget.soundName,
          'albumArtUrl': widget.albumArtUrl,
          'creatorUsername': widget.creatorUsername,
          'timestamp': FieldValue.serverTimestamp(),
        });
        setState(() {
          _isFavorited = true;
        });
        debugPrint('❤️ Added to favorites: ${widget.soundId}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to favorites'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update favorites'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _playSound() async {
    try {
      if (_isPlayingSound) {
        await _audioPlayer.pause();
        setState(() {
          _isPlayingSound = false;
        });
      } else {
        if (widget.soundUrl != null && widget.soundUrl!.isNotEmpty) {
          await _audioPlayer.play(UrlSource(widget.soundUrl!));
          debugPrint('🎵 Playing sound: ${widget.soundName}');
        } else {
          // If no sound URL, show message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sound preview not available'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error playing sound: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to play sound'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

// 🆕 UPDATED: Initial load - first 6 only (pagination)
  Future<void> _loadVideosWithSound() async {
    if (mounted) setState(() { _isLoading = true; _lastDocument = null; });

    try {
      debugPrint('🎵 Loading first $_pageSize videos with sound: ${widget.soundId}');

      Query query = _db
          .collection('media_posts')
          .where('audio_id', isEqualTo: widget.soundId)
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);

      final snapshot = await query.get();

      // Total count (separate lightweight query)
      final countSnapshot = await _db
          .collection('media_posts')
          .where('audio_id', isEqualTo: widget.soundId)
          .count()
          .get();
      _totalVideos = countSnapshot.count ?? snapshot.docs.length;

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }

      _videosWithThisSound = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'uid': data['uid'] ?? '',
          'username': data['username'] ?? 'Unknown',
          'media_url': data['media_url'] ?? '',
          'thumbnail_url': data['thumbnail_url'] ?? '',
          'type': data['type'] ?? 'video',
          'description': data['description'] ?? '',
          'timestamp': data['timestamp'],
          'likes': data['likes'] ?? 0,
          'views': data['views'] ?? data['viewCount'] ?? 0,
        };
      }).toList();

      _hasMorePosts = snapshot.docs.length >= _pageSize;

      debugPrint('✅ Initial load: ${_videosWithThisSound.length} videos (total: $_totalVideos)');

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Error loading videos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sound',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              // Sound Info Header with Hero Animation
              _buildSoundHeader(),

              // Stats & Content Grid
              Expanded(
                child: _isLoading ? _buildShimmerGrid() : _buildVideosGrid(),
              ),
            ],
          ),

          // Sticky "Use Sound" Button at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildStickyUseButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Top Row: Profile Image + Sound Name + Favorite Button
          _buildCreatorSection(),

          const SizedBox(height: 24),

          // Hero Animation - Album Art / Vinyl Disc
          Hero(
            tag: widget.heroTag,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                // Gentle pulsing effect
                double scale = 1.0 + (_pulseController.value * 0.05);

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[900],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3B5C).withOpacity(0.3),
                          blurRadius: 20 + (_pulseController.value * 10),
                          spreadRadius: 5 + (_pulseController.value * 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: widget.albumArtUrl != null &&
                          widget.albumArtUrl!.isNotEmpty
                          ? Image.network(
                        widget.albumArtUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.music_note,
                            size: 50,
                            color: Colors.white54,
                          );
                        },
                      )
                          : const Icon(
                        Icons.music_note,
                        size: 50,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Video Count
          Text(
            '$_totalVideos ${_totalVideos == 1 ? 'video' : 'videos'}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 20),

          // Play Sound Button (Center of page)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _playSound,
              icon: Icon(
                _isPlayingSound ? Icons.pause_circle : Icons.play_circle_filled,
                color: Colors.white,
                size: 24,
              ),
              label: Text(
                _isPlayingSound ? 'Pause Sound' : 'Play Sound',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B5C),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
// 🆕 NEW METHOD: Creator profile section (Firestore data use කරනවා)
  Widget _buildCreatorSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Creator avatar
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: ClipOval(
            child: _isLoadingCreator
                ? Container(
              color: Colors.grey[800],
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white54,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
                : (_resolvedCreatorProfileUrl != null &&
                _resolvedCreatorProfileUrl!.isNotEmpty
                ? Image.network(
              _resolvedCreatorProfileUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildDefaultProfileIcon(),
            )
                : _buildDefaultProfileIcon()),
          ),
        ),

        const SizedBox(width: 12),

        // Sound name + creator name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.soundName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _resolvedCreatorUsername ?? widget.creatorUsername ?? 'Original Sound',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Favorite button
        GestureDetector(
          onTap: _toggleFavorite,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isFavorited
                  ? Colors.red.withOpacity(0.2)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: _isFavorited
                    ? Colors.red
                    : Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              _isFavorited ? Icons.favorite : Icons.favorite_border,
              color: _isFavorited ? Colors.red : Colors.white,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildDefaultProfileIcon() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(
        Icons.person,
        color: Colors.white54,
        size: 30,
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[900]!,
      highlightColor: Colors.grey[800]!,
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 9 / 16,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: 12,
        itemBuilder: (context, index) {
          return Container(
            color: Colors.grey[900],
          );
        },
      ),
    );
  }

  Widget _buildVideosGrid() {
    if (_videosWithThisSound.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.video_library_outlined,
              size: 80,
              color: Colors.white54,
            ),
            SizedBox(height: 16),
            Text(
              'No videos with this sound yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white54,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Be the first to create one!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      );
    }

    // 🆕 CustomScrollView with pagination support
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverGrid(
          delegate: SliverChildBuilderDelegate(
                (context, index) =>
                _buildVideoThumbnail(_videosWithThisSound[index]),
            childCount: _videosWithThisSound.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 9 / 16,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
        ),
        // 🆕 Load more indicator
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80, top: 8),
            child: _isLoadingMore
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF3B5C),
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
                : _hasMorePosts
                ? const SizedBox(height: 16)
                : Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'All ${_totalVideos} videos loaded',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildVideoThumbnail(Map<String, dynamic> video) {
    final thumbnailUrl = video['thumbnail_url'] ?? video['media_url'];
    final viewCount = video['views'] ?? 0;

    return GestureDetector(
      onTap: () {
        // Navigate to video player or open in ForYou feed
        debugPrint('🎬 Opening video: ${video['id']}');
        // TODO: Implement navigation to video detail
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening video...'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        color: Colors.grey[900],
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Thumbnail
            if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
              Image.network(
                thumbnailUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      size: 40,
                      color: Colors.white54,
                    ),
                  );
                },
              )
            else
              const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  size: 40,
                  color: Colors.white54,
                ),
              ),

            // Gradient Overlay (for view count readability)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),

            // Play Icon (top left)
            const Positioned(
              top: 8,
              left: 8,
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 4,
                  ),
                ],
              ),
            ),

            // View Count (bottom left)
            Positioned(
              bottom: 6,
              left: 8,
              child: Row(
                children: [
                  const Icon(
                    Icons.remove_red_eye,
                    color: Colors.white,
                    size: 14,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(viewCount),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 4,
                        ),
                      ],
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

  Widget _buildStickyUseButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _onUseThisSound,
            icon: const Icon(
              Icons.video_call,
              color: Colors.white,
              size: 24,
            ),
            label: const Text(
              'Use Sound',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B5C),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  void _onUseThisSound() {
    // TODO: Navigate to video creation screen with this sound pre-selected
    debugPrint('🎵 Use this sound: ${widget.soundId}');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.videocam, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Opening camera with this sound...',
                style: TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF3B5C),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );

    // TODO: Navigate to camera/recording screen
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => CameraRecordingScreen(
    //       selectedSound: {
    //         'soundId': widget.soundId,
    //         'soundName': widget.soundName,
    //         'soundUrl': widget.soundUrl,
    //         'albumArtUrl': widget.albumArtUrl,
    //       },
    //     ),
    //   ),
    // );

  }
}