import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 🎵 Sounds Tab - Display saved sounds and audio content
class TabSounds extends StatefulWidget {
  const TabSounds({Key? key}) : super(key: key);

  @override
  State<TabSounds> createState() => _TabSoundsState();
}

class _TabSoundsState extends State<TabSounds> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _sounds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSounds();
  }

  Future<void> _loadSounds() async {
    try {
      setState(() => _isLoading = true);

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('🎵 Loading sounds for UID: ${currentUser.uid}');

      // Load saved posts with category 'Sounds'
      final savedSnapshot = await _db
          .collection('users')
          .doc(currentUser.uid)
          .collection('saved_posts')
          .where('category', isEqualTo: 'Sounds')
          .orderBy('saved_at', descending: true)
          .get();

      _sounds.clear();

      for (var savedDoc in savedSnapshot.docs) {
        final postId = savedDoc.data()['post_id'] as String?;

        if (postId != null) {
          final postDoc = await _db.collection('media_posts').doc(postId).get();

          if (postDoc.exists) {
            final postData = postDoc.data()!;

            // Only add audio/sound posts
            final type = postData['type'] ?? postData['mediaType'] ?? 'image';
            if (type == 'audio' || type == 'sound') {
              _sounds.add({
                'id': postDoc.id,
                'saved_doc_id': savedDoc.id,
                'media_url': postData['media_url'] ?? postData['mediaUrl'] ?? '',
                'thumbnail_url': postData['thumbnail_url'] ?? postData['thumbnailUrl'] ?? '',
                'type': type,
                'title': postData['title'] ?? postData['description'] ?? 'Untitled',
                'artist': postData['artist'] ?? postData['username'] ?? 'Unknown Artist',
                'duration': postData['duration'] ?? '00:00',
                'plays': postData['plays'] ?? postData['views'] ?? 0,
                'saved_at': savedDoc.data()['saved_at'],
              });
            }
          }
        }
      }

      debugPrint('✅ Loaded ${_sounds.length} sounds');
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Error loading sounds: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF3B5C),
        ),
      );
    }

    if (_sounds.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadSounds,
      color: const Color(0xFFFF3B5C),
      backgroundColor: const Color(0xFF2A2A2A),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sounds.length,
        itemBuilder: (context, index) {
          return _buildSoundItem(_sounds[index], index);
        },
      ),
    );
  }

  Widget _buildSoundItem(Map<String, dynamic> sound, int index) {
    final title = sound['title'] as String;
    final artist = sound['artist'] as String;
    final duration = sound['duration'] as String;
    final plays = sound['plays'] as int;
    final thumbnailUrl = sound['thumbnail_url'] ?? '';

    return GestureDetector(
      onTap: () {
        debugPrint('🎵 Playing sound: ${sound['id']}');
        // TODO: Play sound
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF3A3A3A),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Thumbnail with play icon
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF1A1A1A),
                  ),
                  child: thumbnailUrl.isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF3B5C),
                          strokeWidth: 2,
                        ),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.music_note,
                        color: Color(0xFF666666),
                      ),
                    ),
                  )
                      : const Icon(
                    Icons.music_note,
                    color: Color(0xFF666666),
                    size: 28,
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B5C),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 12),

            // Title and artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        artist,
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: Color(0xFF666666),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatPlayCount(plays),
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Duration
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                duration,
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // More options
            IconButton(
              icon: const Icon(
                Icons.more_vert,
                color: Color(0xFF666666),
                size: 20,
              ),
              onPressed: () {
                _showSoundOptions(sound);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  void _showSoundOptions(Map<String, dynamic> sound) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1F1F1F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF666666),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.play_circle_outline, color: Colors.white),
              title: const Text(
                'Play Sound',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                debugPrint('🎵 Play: ${sound['title']}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Colors.white),
              title: const Text(
                'Share',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                debugPrint('🎵 Share: ${sound['title']}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFFF3B5C)),
              title: const Text(
                'Remove from Saved',
                style: TextStyle(color: Color(0xFFFF3B5C), fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _removeSound(sound);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _removeSound(Map<String, dynamic> sound) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _db
          .collection('users')
          .doc(currentUser.uid)
          .collection('saved_posts')
          .doc(sound['saved_doc_id'])
          .delete();

      await _loadSounds();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sound removed from saved'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error removing sound: $e');
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B5C).withOpacity(0.05),
              borderRadius: BorderRadius.circular(110),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.music_note_rounded,
                size: 64,
                color: Color(0xFF666666),
              ),
              SizedBox(height: 24),
              Text(
                'No saved sounds yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF888888),
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Save sounds to listen later',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF666666),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatPlayCount(int plays) {
    if (plays >= 1000000) {
      return '${(plays / 1000000).toStringAsFixed(1)}M plays';
    } else if (plays >= 1000) {
      return '${(plays / 1000).toStringAsFixed(1)}K plays';
    }
    return '$plays plays';
  }
}