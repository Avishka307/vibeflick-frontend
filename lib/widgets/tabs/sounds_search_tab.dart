import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../components/skeleton_loaders.dart';

class SoundsSearchTab extends StatefulWidget {
  final String query;

  const SoundsSearchTab({
    super.key,
    required this.query,
  });

  @override
  State<SoundsSearchTab> createState() => _SoundsSearchTabState();
}

class _SoundsSearchTabState extends State<SoundsSearchTab>
    with AutomaticKeepAliveClientMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _sounds = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSounds();
  }

  Future<void> _loadSounds() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final query = widget.query.toLowerCase();

      debugPrint('🎵 Searching sounds for: $query');

      final snapshot = await _db
          .collection('media_posts')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      // ✅ DEBUG: fields බලන්න
      for (var doc in snapshot.docs) {
        final data = doc.data();
        debugPrint('📄 Post: ${doc.id}');
        debugPrint('   audio_id: ${data['audio_id']}');
        debugPrint('   audio_name: ${data['audio_name']}');
        debugPrint('   sound_url: ${data['sound_url']}');
      }
      // Group by audio_id and count videos
      final Map<String, Map<String, dynamic>> soundsMap = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final audioId = data['audio_id'] as String?; // ← මේක නැතුව තිබුණා!

        if (audioId == null || audioId.isEmpty) continue;

        final rawAudioName = data['audio_name'] ?? 'Original Sound';
        final audioName = _cleanAudioName(rawAudioName).toLowerCase();

        if (!audioName.contains(query)) continue;

        if (soundsMap.containsKey(audioId)) {
          soundsMap[audioId]!['videos'] += 1;
        } else {
          soundsMap[audioId] = {
            'audio_id': audioId,
            'audio_name': _cleanAudioName(rawAudioName),
            'album_art_url': data['album_art_url'],
            'sound_url': data['sound_url'],
            'videos': 1,
          };
        }
      }

      _sounds = soundsMap.values.toList()
        ..sort((a, b) => (b['videos'] as int).compareTo(a['videos'] as int));

      debugPrint('✅ Found ${_sounds.length} sounds');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading sounds: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SkeletonLoaders.sound(),
          );
        },
      );
    }

    if (_sounds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_off_outlined,
                size: 60,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No sounds found',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sounds.length,
      itemBuilder: (context, index) {
        final sound = _sounds[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildSoundCard(sound),
        );
      },
    );
  }

  Widget _buildSoundCard(Map<String, dynamic> sound) {
    return GestureDetector(
      onTap: () {
        // Navigate to sound detail page
        debugPrint('🎵 Sound tapped: ${sound['audio_name']}');
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF0050),
                    Color(0xFFFFB800),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.music_note,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sound['audio_name'],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0050).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.video_library_rounded,
                          size: 12,
                          color: Color(0xFFFF0050),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${sound['videos']} videos',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF0050),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white24,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  String _cleanAudioName(String? rawName) {
    if (rawName == null || rawName.isEmpty) return 'Original Sound';

    final hashPattern = RegExp(r'^[a-f0-9]{32}$', caseSensitive: false);
    if (hashPattern.hasMatch(rawName.trim())) return 'Custom Sound';

    if (rawName.contains('/') || rawName.contains(r'\')) {
      final fileName = rawName
          .split(RegExp(r'[/\\]'))
          .last;
      final nameWithoutExt = fileName.replaceAll(
          RegExp(r'\.(mp3|aac|wav|m4a|ogg|flac)$', caseSensitive: false), '');
      final cleaned = nameWithoutExt.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
      return cleaned.isNotEmpty ? cleaned : 'Custom Sound';
    }

    return rawName.trim();
  }
}