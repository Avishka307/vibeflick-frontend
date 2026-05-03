import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:io';

class TrimSegment {
  double start;
  double end;
  double speed;
  TrimSegment({required this.start, required this.end, this.speed = 1.0});
}

class TrimBottomSheet extends StatefulWidget {
  final File mediaFile;
  const TrimBottomSheet({super.key, required this.mediaFile});

  @override
  State<TrimBottomSheet> createState() => _TrimBottomSheetState();
}

class _TrimBottomSheetState extends State<TrimBottomSheet> {
  late VideoPlayerController _vc;
  bool _ready = false;

  double _start = 0.0;
  double _end   = 1.0;
  double _head  = 0.0;

  static const int _thumbCount = 10;
  final List<Uint8List?> _thumbs = List.filled(_thumbCount, null);

  static const double _stripH  = 58.0;
  static const double _handleW = 18.0;
  static const double _minSec  = 1.0;

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _vc = VideoPlayerController.file(widget.mediaFile);
    await _vc.initialize();
    _vc.setLooping(false);
    _vc.play();
    if (!mounted) return;
    setState(() => _ready = true);

    _ticker = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted || !_ready) return;
      final total = _vc.value.duration.inMilliseconds;
      if (total == 0) return;
      final pos = _vc.value.position.inMilliseconds / total;
      if (pos >= _end) {
        _vc.seekTo(Duration(milliseconds: (_start * total).toInt()));
      }
      if (mounted) setState(() => _head = pos.clamp(0.0, 1.0));
    });

    _loadThumbnails();
  }

  Future<void> _loadThumbnails() async {
    final totalMs = _vc.value.duration.inMilliseconds;
    if (totalMs == 0) return;

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
        if (mounted) {
          setState(() => _thumbs[i] = bytes);
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _vc.dispose();
    super.dispose();
  }

  double get _totalSec => _ready ? _vc.value.duration.inMilliseconds / 1000.0 : 0.0;
  double get _selSec   => (_end - _start) * _totalSec;

  String _fmtDuration(double s) {
    if (s < 60) return '${s.toStringAsFixed(1)}s';
    final m = s ~/ 60;
    return '${m}m ${(s % 60).toStringAsFixed(1)}s';
  }

  void _seekTo(double norm) {
    if (!_ready) return;
    _vc.seekTo(Duration(milliseconds: (norm * _vc.value.duration.inMilliseconds).toInt()));
  }

  void _apply() {
    if (!_ready || _selSec < _minSec) return;
    final total   = _vc.value.duration.inMilliseconds;
    final startMs = (_start * total).toInt();
    final endMs   = (_end   * total).toInt();
    Navigator.pop(context, {
      'startMs': startMs,
      'endMs':   endMs,
      'speed':   1.0,
      'splits':  <double>[],
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _buildStrip(),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
                Text(
                  'Video duration:${_fmtDuration(_selSec)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                GestureDetector(
                  onTap: _selSec < _minSec ? null : _apply,
                  child: Icon(
                    Icons.check,
                    color: _selSec < _minSec ? Colors.white30 : Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildStrip() {
    return LayoutBuilder(builder: (_, box) {
      final W      = box.maxWidth;
      final startX = _start * W;
      final endX   = _end   * W;
      final headX  = (_head  * W).clamp(0.0, W - 2.0);

      return SizedBox(
        height: _stripH,
        child: GestureDetector(
          onTapDown: (d) => _seekTo((d.localPosition.dx / W).clamp(0.0, 1.0)),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [

              // Thumbnail frames
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: List.generate(_thumbCount, (i) {
                      final bytes = _thumbs[i];
                      return Expanded(
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
                              color: Colors.white30,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              // Dark overlay left
              if (startX > 0)
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  width: startX,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomLeft: Radius.circular(6),
                    ),
                    child: Container(color: Colors.black.withOpacity(0.65)),
                  ),
                ),

              // Dark overlay right
              if (endX < W)
                Positioned(
                  left: endX, top: 0, bottom: 0, right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                    child: Container(color: Colors.black.withOpacity(0.65)),
                  ),
                ),

              // White border top/bottom of selection
              Positioned(
                left: startX,
                top: 0,
                bottom: 0,
                width: (endX - startX).clamp(0.0, W - startX),
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top:    BorderSide(color: Colors.white, width: 2.5),
                      bottom: BorderSide(color: Colors.white, width: 2.5),
                    ),
                  ),
                ),
              ),

              // Playhead
              Positioned(
                left: headX,
                top: 4, bottom: 4,
                width: 2.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Left handle
              Positioned(
                left: startX - _handleW / 2,
                top: 0, bottom: 0,
                width: _handleW,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) => _vc.pause(),
                  onHorizontalDragUpdate: (d) {
                    final minGap = _totalSec > 0 ? _minSec / _totalSec : 0.01;
                    final ns = (_start + d.delta.dx / W).clamp(0.0, _end - minGap);
                    if (ns == _start) return;
                    HapticFeedback.selectionClick();
                    setState(() => _start = ns);
                    _seekTo(ns);
                  },
                  onHorizontalDragEnd: (_) => _vc.play(),
                  child: _handle(isStart: true),
                ),
              ),

              // Right handle
              Positioned(
                left: endX - _handleW / 2,
                top: 0, bottom: 0,
                width: _handleW,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) => _vc.pause(),
                  onHorizontalDragUpdate: (d) {
                    final minGap = _totalSec > 0 ? _minSec / _totalSec : 0.01;
                    final ne = (_end + d.delta.dx / W).clamp(_start + minGap, 1.0);
                    if (ne == _end) return;
                    HapticFeedback.selectionClick();
                    setState(() => _end = ne);
                    _seekTo(ne);
                  },
                  onHorizontalDragEnd: (_) => _vc.play(),
                  child: _handle(isStart: false),
                ),
              ),

            ],
          ),
        ),
      );
    });
  }

  Widget _handle({required bool isStart}) {
    return Container(
      width: _handleW,
      height: _stripH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.horizontal(
          left:  isStart ? const Radius.circular(5) : Radius.zero,
          right: isStart ? Radius.zero : const Radius.circular(5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < 3; i++) ...[
            Container(
              width: 3, height: 1.5,
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            if (i < 2) const SizedBox(height: 3),
          ],
        ],
      ),
    );
  }
}