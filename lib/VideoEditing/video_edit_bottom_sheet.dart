import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

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

  // ── Timeline state ─────────────────────────────────────────────────────────
  double _playhead  = 0.0;
  double _clipStart = 0.0;
  double _clipEnd   = 1.0;
  double _speed     = 1.0;
  bool   _deleted   = false;

  // ── Undo ───────────────────────────────────────────────────────────────────
  final List<Map<String, double>> _history = [];

  // ── Thumbnails ─────────────────────────────────────────────────────────────
  static const int _thumbCount = 10;
  final List<Uint8List?> _thumbs = List.filled(_thumbCount, null);

  // ── Layout ─────────────────────────────────────────────────────────────────
  static const double _stripH   = 56.0;
  static const double _thumbW   = 56.0;
  static const double _stripW   = _thumbCount * _thumbW;

  final ScrollController _stripScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadThumbnails();
  }

  Future<void> _loadThumbnails() async {
    // Use a dummy 10s duration if we can't get actual duration
    // In real usage this would come from the VideoPlayerController
    const totalMs = 10000;

    for (int i = 0; i < _thumbCount; i++) {
      final posMs = (totalMs / _thumbCount * i).toInt();
      try {
        final bytes = await VideoThumbnail.thumbnailData(
          video: widget.mediaFile.path,
          imageFormat: ImageFormat.JPEG,
          timeMs: posMs,
          maxHeight: 80,
          quality: 50,
        );
        if (mounted) setState(() => _thumbs[i] = bytes);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _stripScroll.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  double get _clipDurSec => (_clipEnd - _clipStart) * 100.0;
  String _fmtSec(double s) => '${s.toStringAsFixed(1)}s';

  void _undo() {
    if (_history.isEmpty) return;
    final prev = _history.removeLast();
    setState(() {
      _clipStart = prev['start']!;
      _clipEnd   = prev['end']!;
      _speed     = prev['speed']!;
      _deleted   = false;
    });
    HapticFeedback.selectionClick();
  }

  void _saveHistory() {
    _history.add({'start': _clipStart, 'end': _clipEnd, 'speed': _speed});
  }

  void _split() {
    if (_playhead <= _clipStart || _playhead >= _clipEnd) return;
    _saveHistory();
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

  void _pickSpeed() {
    final speeds = [0.3, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
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
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
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
                          fontSize: 11,
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
      ),
    );
  }

  void _delete() {
    _saveHistory();
    setState(() => _deleted = true);
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Clip deleted'),
        action: SnackBarAction(label: 'Undo', onPressed: _undo, textColor: Colors.blue),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _apply() {
    Navigator.pop(context, {
      'clipStart': _clipStart,
      'clipEnd':   _clipEnd,
      'speed':     _speed,
      'deleted':   _deleted,
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Undo button (right aligned) ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _history.isEmpty ? null : _undo,
                child: Icon(
                  Icons.replay,
                  color: _history.isEmpty ? Colors.white24 : Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),

          // ── Time ruler ───────────────────────────────────────────────────
          _buildRuler(),

          const SizedBox(height: 4),

          // ── Clip strip ───────────────────────────────────────────────────
          _buildClipStrip(),

          const SizedBox(height: 16),

          // ── Split | Speed | Delete ────────────────────────────────────────
          _buildActionRow(),

          const SizedBox(height: 14),

          // ── Back | Next ───────────────────────────────────────────────────
          _buildNavRow(),

          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ── Time ruler ──────────────────────────────────────────────────────────────

  Widget _buildRuler() {
    final ticks = <double>[0, 2, 4, 6, 8, 10];
    return SizedBox(
      height: 18,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _stripScroll,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: ticks.map((t) {
                  final label =
                      '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toInt().toString().padLeft(2, '0')}';
                  return SizedBox(
                    width: _thumbW * _thumbCount / ticks.length,
                    child: Text(
                      label,
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Space for + button
          const SizedBox(width: 54),
        ],
      ),
    );
  }

  // ── Clip strip ──────────────────────────────────────────────────────────────

  Widget _buildClipStrip() {
    return SizedBox(
      height: _stripH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Scrollable strip
          Expanded(
            child: SingleChildScrollView(
              controller: _stripScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _stripW,
                height: _stripH,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [

                    // ── Thumbnails ─────────────────────────────────────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Row(
                        children: List.generate(_thumbCount, (i) {
                          final bytes = _thumbs[i];
                          return SizedBox(
                            width: _thumbW,
                            height: _stripH,
                            child: bytes != null
                                ? Image.memory(
                              bytes,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            )
                                : Container(
                              color: Colors.grey[850],
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // ── White selection border ─────────────────────────────
                    Positioned(
                      left: _clipStart * _stripW,
                      top: 0,
                      bottom: 0,
                      width: (_clipEnd - _clipStart) * _stripW,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),

                    // ── Duration badge ─────────────────────────────────────
                    Positioned(
                      left: _clipStart * _stripW + 4,
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

                    // ── Speed badge ────────────────────────────────────────
                    if (_speed != 1.0)
                      Positioned(
                        left: _clipStart * _stripW + 4,
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

                    // ── Left red handle ────────────────────────────────────
                    Positioned(
                      left: _clipStart * _stripW,
                      top: 0, bottom: 0,
                      width: 8,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (d) {
                          final ns = (_clipStart + d.delta.dx / _stripW)
                              .clamp(0.0, _clipEnd - 0.02);
                          setState(() => _clipStart = ns);
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.horizontal(
                              left: Radius.circular(4),
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.chevron_left, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ),

                    // ── Right white handle ─────────────────────────────────
                    Positioned(
                      left: _clipEnd * _stripW - 8,
                      top: 0, bottom: 0,
                      width: 8,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (d) {
                          final ne = (_clipEnd + d.delta.dx / _stripW)
                              .clamp(_clipStart + 0.02, 1.0);
                          setState(() => _clipEnd = ne);
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.horizontal(
                              right: Radius.circular(4),
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.chevron_right, color: Colors.black54, size: 14),
                          ),
                        ),
                      ),
                    ),

                    // ── Playhead ───────────────────────────────────────────
                    Positioned(
                      left: (_playhead * _stripW).clamp(0.0, _stripW - 2.5),
                      top: 0, bottom: 0,
                      width: 2.5,
                      child: Container(color: Colors.white),
                    ),

                  ],
                ),
              ),
            ),
          ),

          // ── + Add clip button ──────────────────────────────────────────────
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 44,
              height: _stripH,
              margin: const EdgeInsets.only(left: 6, right: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.add, color: Colors.black, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  // ── Action row ──────────────────────────────────────────────────────────────

  Widget _buildActionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _actionBtn(icon: Icons.vertical_split_outlined, label: 'Split', onTap: _split),
        const SizedBox(width: 44),
        _actionBtn(icon: Icons.speed, label: 'Speed', onTap: _pickSpeed),
        const SizedBox(width: 44),
        _actionBtn(icon: Icons.delete_outline, label: 'Delete', onTap: _deleted ? null : _delete, dimmed: _deleted),
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
          Icon(icon, color: dimmed ? Colors.white24 : Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: dimmed ? Colors.white24 : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ── Nav row ─────────────────────────────────────────────────────────────────

  Widget _buildNavRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Back',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          GestureDetector(
            onTap: _apply,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D6A),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Next',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}