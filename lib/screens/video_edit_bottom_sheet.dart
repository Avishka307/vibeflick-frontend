import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

// ─────────────────────────────────────────────────────────────────────────────
// VideoEditBottomSheet  —  Clip editor (matches reference screenshot)
//
//  ♫ Add music
//  ┌──────────────┐
//  │  video prev  │
//  └──────────────┘
//  00:02 / 01:29   ▶   ↺
//  00:00  ·  00:02  ·  00:04
//  [━━━━━ clip strip ━━━━━ ┼ +]
//  Split   Speed   Delete
//  Back              Next
// ─────────────────────────────────────────────────────────────────────────────

class VideoEditBottomSheet extends StatefulWidget {
  final File mediaFile;
  final bool isVideo;

  const VideoEditBottomSheet({
    super.key,
    required this.mediaFile,
    required this.isVideo,
  });

  @override
  State<VideoEditBottomSheet> createState() => _VideoEditBottomSheetState();
}

class _VideoEditBottomSheetState extends State<VideoEditBottomSheet> {

  // ── Video ──────────────────────────────────────────────────────────────────
  VideoPlayerController? _vc;
  bool _ready   = false;
  bool _playing = false;

  // ── Timeline state ─────────────────────────────────────────────────────────
  double _playhead   = 0.0;   // 0.0 – 1.0
  double _clipStart  = 0.0;
  double _clipEnd    = 1.0;
  double _speed      = 1.0;
  bool   _deleted    = false;

  // ── Undo stack (simple) ────────────────────────────────────────────────────
  final List<Map<String, double>> _history = [];

  // ── Clip strip scroll ──────────────────────────────────────────────────────
  final ScrollController _stripScroll = ScrollController();

  // ── Thumbnails placeholder ─────────────────────────────────────────────────
  static const int _thumbCount = 10;
  late final List<Color> _tints;

  Timer? _ticker;

  // ── Layout constants ───────────────────────────────────────────────────────
  static const double _stripH = 56.0;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(17);
    final palette = [
      const Color(0xFF5C3317),
      const Color(0xFF2B4A18),
      const Color(0xFF1B3050),
      const Color(0xFF4A3520),
      const Color(0xFF3A2040),
    ];
    _tints = List.generate(_thumbCount, (_) => palette[rng.nextInt(palette.length)]);

    if (widget.isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    final vc = VideoPlayerController.file(widget.mediaFile);
    await vc.initialize();
    vc.setLooping(false);
    if (!mounted) return;
    setState(() {
      _vc    = vc;
      _ready = true;
    });
    // Playhead ticker
    _ticker = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted || _vc == null) return;
      final total = _vc!.value.duration.inMilliseconds;
      if (total == 0) return;
      final pos = _vc!.value.position.inMilliseconds / total;
      if (pos >= _clipEnd) {
        _vc!.seekTo(Duration(milliseconds: (_clipStart * total).toInt()));
        if (!_playing) _vc!.pause();
      }
      if (mounted) setState(() => _playhead = pos.clamp(0.0, 1.0));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _vc?.dispose();
    _stripScroll.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Duration get _position => _ready
      ? _vc!.value.position
      : Duration.zero;

  Duration get _total => _ready
      ? _vc!.value.duration
      : Duration.zero;

  String _fmtDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _clipDurSec =>
      (_clipEnd - _clipStart) * (_total.inMilliseconds / 1000.0);

  String _fmtSec(double s) => '${s.toStringAsFixed(1)}s';

  void _togglePlay() {
    if (!_ready) return;
    setState(() => _playing = !_playing);
    _playing ? _vc!.play() : _vc!.pause();
  }

  void _undo() {
    if (_history.isEmpty) return;
    final prev = _history.removeLast();
    setState(() {
      _clipStart = prev['start']!;
      _clipEnd   = prev['end']!;
      _speed     = prev['speed']!;
      _deleted   = false;
    });
    _vc?.setPlaybackSpeed(_speed);
    HapticFeedback.selectionClick();
  }

  void _saveHistory() {
    _history.add({'start': _clipStart, 'end': _clipEnd, 'speed': _speed});
  }

  // ── Split at current playhead ───────────────────────────────────────────────
  void _split() {
    if (_playhead <= _clipStart || _playhead >= _clipEnd) return;
    _saveHistory();
    // For demo: split shortens end to playhead
    setState(() => _clipEnd = _playhead);
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Clip split at current position'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.blueGrey,
      ),
    );
  }

  // ── Speed picker ────────────────────────────────────────────────────────────
  void _pickSpeed() {
    final speeds = [0.3, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Playback Speed',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: speeds.map((s) {
                  final sel = _speed == s;
                  return GestureDetector(
                    onTap: () {
                      _saveHistory();
                      setState(() => _speed = s);
                      _vc?.setPlaybackSpeed(s);
                      HapticFeedback.selectionClick();
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: sel ? Colors.white : Colors.white12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${s}x',
                          style: TextStyle(
                            color: sel ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // ── Delete clip ─────────────────────────────────────────────────────────────
  void _delete() {
    _saveHistory();
    setState(() => _deleted = true);
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Clip deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: _undo,
          textColor: Colors.blue,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Apply ───────────────────────────────────────────────────────────────────
  void _apply() {
    if (!_ready) { Navigator.pop(context); return; }
    final total   = _vc!.value.duration.inMilliseconds;
    final startMs = (_clipStart * total).toInt();
    final endMs   = (_clipEnd   * total).toInt();
    Navigator.pop(context, {
      'startMs': startMs,
      'endMs':   endMs,
      'speed':   _speed,
      'deleted': _deleted,
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Add music ────────────────────────────────────────────────
            _buildAddMusic(),

            // ── Video preview ────────────────────────────────────────────
            Expanded(child: _buildVideoPreview()),

            // ── Controls ─────────────────────────────────────────────────
            _buildControls(),

            // ── Time ruler ───────────────────────────────────────────────
            _buildRuler(),

            // ── Clip strip ───────────────────────────────────────────────
            _buildClipStrip(),

            const SizedBox(height: 20),

            // ── Action row: Split | Speed | Delete ───────────────────────
            _buildActionRow(),

            const SizedBox(height: 14),

            // ── Nav: Back | Next ─────────────────────────────────────────
            _buildNavRow(),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Add music
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildAddMusic() {
    return GestureDetector(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.music_note, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text(
              'Add music',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Video preview (small centered, matches screenshot)
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildVideoPreview() {
    return Center(
      child: GestureDetector(
        onTap: _togglePlay,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 200),
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_ready)
                AspectRatio(
                  aspectRatio: _vc!.value.aspectRatio,
                  child: VideoPlayer(_vc!),
                )
              else if (widget.isVideo)
                const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              else
                Image.file(widget.mediaFile, fit: BoxFit.contain),

              // Play icon overlay (only when paused)
              if (_ready && !_vc!.value.isPlaying)
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                ),

              // Deleted overlay
              if (_deleted)
                Container(
                  color: Colors.black87,
                  child: const Center(
                    child: Text(
                      'Deleted',
                      style: TextStyle(color: Colors.white60, fontSize: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Controls: 00:02 / 01:29  ▶  ↺
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Current / total time
          Text(
            '${_fmtDur(_position)} / ${_fmtDur(_total)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),

          // Play / Pause (centered)
          const Spacer(),
          GestureDetector(
            onTap: _togglePlay,
            child: Icon(
              _playing ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 30,
            ),
          ),
          const Spacer(),

          // Undo
          GestureDetector(
            onTap: _history.isEmpty ? null : _undo,
            child: Icon(
              Icons.replay,
              color: _history.isEmpty ? Colors.white24 : Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Time ruler: 00:00 · 00:02 · 00:04 · …
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildRuler() {
    final totalSec = _total.inSeconds.toDouble();
    // Generate tick labels every 2 seconds
    final ticks = <double>[];
    if (totalSec > 0) {
      double t = 0;
      while (t <= totalSec) { ticks.add(t); t += 2; }
    } else {
      ticks.addAll([0, 2, 4, 6]);
    }

    return SizedBox(
      height: 20,
      child: SingleChildScrollView(
        controller: _stripScroll,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: ticks.map((t) {
            final label =
                '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toInt().toString().padLeft(2, '0')}';
            return SizedBox(
              width: 80,
              child: Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(width: 6),
                  const Text('·', style: TextStyle(color: Colors.white24, fontSize: 11)),
                  const Spacer(),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Clip strip
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildClipStrip() {
    return SizedBox(
      height: _stripH + 4,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Scrollable thumbnail strip
          Expanded(
            child: SingleChildScrollView(
              controller: _stripScroll,
              scrollDirection: Axis.horizontal,
              child: LayoutBuilder(builder: (_, box) {
                // Fixed strip width = thumbCount * 56px
                const stripW = _thumbCount * 56.0;

                return SizedBox(
                  width: stripW,
                  height: _stripH,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      // ── Thumbnails ──────────────────────────────────
                      Row(
                        children: List.generate(_thumbCount, (i) {
                          return Container(
                            width: 56,
                            height: _stripH,
                            decoration: BoxDecoration(
                              color: _tints[i % _tints.length],
                              border: Border.all(
                                color: Colors.black,
                                width: 0.5,
                              ),
                            ),
                          );
                        }),
                      ),

                      // ── White border (selected region) ───────────────
                      Positioned(
                        left: _clipStart * stripW,
                        top: 0,
                        bottom: 0,
                        width: (_clipEnd - _clipStart) * stripW,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // ── Duration badge ───────────────────────────────
                      Positioned(
                        left: _clipStart * stripW + 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _fmtSec(_clipDurSec),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // ── Speed badge ──────────────────────────────────
                      if (_speed != 1.0)
                        Positioned(
                          left: _clipStart * stripW + 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${_speed}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      // ── Left red segment handle ──────────────────────
                      Positioned(
                        left: _clipStart * stripW,
                        top: 0,
                        bottom: 0,
                        width: 6,
                        child: GestureDetector(
                          onHorizontalDragUpdate: (d) {
                            final ns = (_clipStart + d.delta.dx / stripW)
                                .clamp(0.0, _clipEnd - 0.02);
                            setState(() => _clipStart = ns);
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Right white handle ───────────────────────────
                      Positioned(
                        left: _clipEnd * stripW - 6,
                        top: 0,
                        bottom: 0,
                        width: 6,
                        child: GestureDetector(
                          onHorizontalDragUpdate: (d) {
                            final ne = (_clipEnd + d.delta.dx / stripW)
                                .clamp(_clipStart + 0.02, 1.0);
                            setState(() => _clipEnd = ne);
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.horizontal(
                                right: Radius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Playhead ─────────────────────────────────────
                      Positioned(
                        left: (_playhead * stripW).clamp(0.0, stripW - 2),
                        top: -4,
                        bottom: -4,
                        width: 2.5,
                        child: Container(color: Colors.white),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),

          // ── + Add clip button ────────────────────────────────────────
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 48,
              height: _stripH,
              margin: const EdgeInsets.only(left: 6, right: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: Colors.black, size: 26),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Action row: Split | Speed | Delete
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildActionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _actionBtn(
          icon: Icons.vertical_split_outlined,
          label: 'Split',
          onTap: _split,
        ),
        const SizedBox(width: 48),
        _actionBtn(
          icon: Icons.speed,
          label: 'Speed',
          onTap: _pickSpeed,
        ),
        const SizedBox(width: 48),
        _actionBtn(
          icon: Icons.delete_outline,
          label: 'Delete',
          onTap: _deleted ? null : _delete,
          dimmed: _deleted,
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool dimmed = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: dimmed ? Colors.white24 : Colors.white, size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: dimmed ? Colors.white24 : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Nav row: Back | Next
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildNavRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Next button
          GestureDetector(
            onTap: _apply,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D6A),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Next',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}