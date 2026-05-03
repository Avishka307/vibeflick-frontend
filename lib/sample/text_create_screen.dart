// ============================================================
//  text_create_screen.dart
//  Text post create කරන සම්පූර්ණ UI screen.
//  Canvas + Style Bar + Top Bar — සියල්ල මෙතන.
// ============================================================

import 'package:flutter/material.dart';

import 'text_post_model.dart';
import 'text_post_controller.dart';

// ---------------------------------------------------------------
//  Constants — Colors, Fonts
// ---------------------------------------------------------------
const _kStickerList = ['🛺', '🥥', '🌴', '🌊', '☕', '🎉', '❤️', '⭐', '🔥', '✨'];

const _kBackgrounds = {
  PostBackground.saffron: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B35), Color(0xFFF7C59F)],
  ),
  PostBackground.ocean: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF023E8A), Color(0xFF48CAE4)],
  ),
  PostBackground.forest: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B4332), Color(0xFF95D5B2)],
  ),
  PostBackground.sunset: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9D0208), Color(0xFFFFBA08)],
  ),
  PostBackground.night: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F0E17), Color(0xFF2E2E3A)],
  ),
  PostBackground.thambili: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE76F51), Color(0xFFF4D35E)],
  ),
};

const _kDarkBackgrounds = {
  PostBackground.ocean,
  PostBackground.forest,
  PostBackground.night,
};

const _kFontStyleLabels = {
  PostFontStyle.clean: 'Clean',
  PostFontStyle.bold: 'Bold',
  PostFontStyle.serif: 'Serif',
  PostFontStyle.boldSerif: 'Bold Serif',
};

TextStyle _buildFontStyle(PostFontStyle fs, double size, Color color) {
  switch (fs) {
    case PostFontStyle.clean:
      return TextStyle(
          fontFamily: 'NotoSansSinhala', fontSize: size, color: color);
    case PostFontStyle.bold:
      return TextStyle(
          fontFamily: 'NotoSansSinhala',
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: color);
    case PostFontStyle.serif:
      return TextStyle(
          fontFamily: 'NotoSerifSinhala', fontSize: size, color: color);
    case PostFontStyle.boldSerif:
      return TextStyle(
          fontFamily: 'NotoSerifSinhala',
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color);
  }
}

// ---------------------------------------------------------------
//  Auto Font Size Calculator
// ---------------------------------------------------------------
double _calcFontSize(int charCount) {
  if (charCount == 0) return 48;
  if (charCount < 30) return 42;
  if (charCount < 80) return 32;
  if (charCount < 150) return 24;
  return 18;
}

// ---------------------------------------------------------------
//  TextCreateScreen
// ---------------------------------------------------------------
class TextCreateScreen extends StatefulWidget {
  const TextCreateScreen({super.key});

  @override
  State<TextCreateScreen> createState() => _TextCreateScreenState();
}

class _TextCreateScreenState extends State<TextCreateScreen> {
  final _textController = TextEditingController();
  final _canvasKey = GlobalKey();
  late final TextPostController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextPostController();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  //  Sticker drop position calculate
  // ---------------------------------------------------------------
  void _onStickerDropped(String emoji, Offset globalOffset) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalOffset);
    final size = box.size;
    _controller.addSticker(
      StickerPlacement(
        emoji: emoji,
        xPercent: (local.dx / size.width * 100).clamp(5, 95),
        yPercent: (local.dy / size.height * 100).clamp(5, 95),
      ),
    );
  }

  // ---------------------------------------------------------------
  //  Build
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final state = _controller.state;

    final isDark = _kDarkBackgrounds.contains(state.background);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final hintColor = isDark
        ? Colors.white.withOpacity(0.4)
        : Colors.black.withOpacity(0.3);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Canvas (ලියන තැන) ───────────────────────────────
            Expanded(
              child: _CanvasArea(
                canvasKey: _canvasKey,
                state: state,
                textColor: textColor,
                hintColor: hintColor,
                isDark: isDark,
                textController: _textController,
                onTextChanged: controller.onTextChanged,
                onStickerDropped: _onStickerDropped,
                onStickerRemoved: controller.removeSticker,
                onPostTapped: () => controller.submitPost(context),
              ),
            ),

            // ── Style Bar ──────────────────────────────────────
            _StyleBar(
              state: state,
              isDark: isDark,
              onBgChanged: controller.onBackgroundChanged,
              onFontChanged: controller.onFontStyleChanged,
              onNearbyChanged: controller.onNearbyToggled,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
//  _CanvasArea Widget
// ---------------------------------------------------------------
class _CanvasArea extends StatelessWidget {
  const _CanvasArea({
    required this.canvasKey,
    required this.state,
    required this.textColor,
    required this.hintColor,
    required this.isDark,
    required this.textController,
    required this.onTextChanged,
    required this.onStickerDropped,
    required this.onStickerRemoved,
    required this.onPostTapped,
  });

  final GlobalKey canvasKey;
  final TextPostState state;
  final Color textColor;
  final Color hintColor;
  final bool isDark;
  final TextEditingController textController;
  final ValueChanged<String> onTextChanged;
  final void Function(String emoji, Offset offset) onStickerDropped;
  final ValueChanged<int> onStickerRemoved;
  final VoidCallback onPostTapped;

  @override
  Widget build(BuildContext context) {
    final fontSize = _calcFontSize(state.text.length);

    return DragTarget<String>(
      onAcceptWithDetails: (details) =>
          onStickerDropped(details.data, details.offset),
      builder: (context, candidateData, rejectedData) {
        return Container(
          key: canvasKey,
          decoration: BoxDecoration(
            gradient: _kBackgrounds[state.background],
          ),
          child: Stack(
            children: [
              // ── Top Bar ──────────────────────────────────────
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    _GlassButton(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                    // Post button
                    _PostButton(state: state, onTap: onPostTapped),
                  ],
                ),
              ),

              // ── Centered Text Field ──────────────────────────
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: _buildFontStyle(
                        state.fontStyle, fontSize, textColor),
                    child: TextField(
                      controller: textController,
                      onChanged: onTextChanged,
                      maxLines: null,
                      textAlign: TextAlign.center,
                      style: _buildFontStyle(
                          state.fontStyle, fontSize, textColor),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'ඔයාගේ හිතේ තියෙන දේ ලියන්න...',
                        hintStyle: _buildFontStyle(
                            state.fontStyle, fontSize, hintColor),
                      ),
                      cursorColor: textColor,
                    ),
                  ),
                ),
              ),

              // ── Placed Stickers ──────────────────────────────
              ...state.stickers.asMap().entries.map((entry) {
                final idx = entry.key;
                final s = entry.value;
                return Positioned(
                  left: s.xPercent / 100 *
                      MediaQuery.of(context).size.width,
                  top: s.yPercent / 100 *
                      (MediaQuery.of(context).size.height * 0.70),
                  child: GestureDetector(
                    onDoubleTap: () => onStickerRemoved(idx),
                    child: _AnimatedSticker(emoji: s.emoji),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------
//  _PostButton Widget — status අනුව වෙනස් වෙනවා
// ---------------------------------------------------------------
class _PostButton extends StatelessWidget {
  const _PostButton({required this.state, required this.onTap});

  final TextPostState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLoading = state.status == PostingStatus.locating ||
        state.status == PostingStatus.uploading;
    final isSuccess = state.status == PostingStatus.success;

    return GestureDetector(
      onTap: state.canPost ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding:
        const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: isSuccess
              ? const Color(0xFF4CAF50)
              : state.canPost
              ? Colors.white
              : Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.black,
          ),
        )
            : Text(
          isSuccess ? '✓ Posted!' : 'පළ කරන්න',
          style: TextStyle(
            color: isSuccess ? Colors.white : Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
//  _StyleBar Widget — Background / Font / Stickers / Nearby
// ---------------------------------------------------------------
class _StyleBar extends StatelessWidget {
  const _StyleBar({
    required this.state,
    required this.isDark,
    required this.onBgChanged,
    required this.onFontChanged,
    required this.onNearbyChanged,
  });

  final TextPostState state;
  final bool isDark;
  final ValueChanged<PostBackground> onBgChanged;
  final ValueChanged<PostFontStyle> onFontChanged;
  final ValueChanged<bool> onNearbyChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0F14),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Background
          _SectionLabel(label: 'Background'),
          const SizedBox(height: 10),
          _BackgroundBubbles(
              selected: state.background, onChanged: onBgChanged),

          const SizedBox(height: 18),

          // Font Styles
          _SectionLabel(label: 'Font Style'),
          const SizedBox(height: 10),
          _FontStyleRow(
              selected: state.fontStyle, onChanged: onFontChanged),

          const SizedBox(height: 18),

          // Stickers
          _SectionLabel(label: 'Stickers — Drag to Post'),
          const SizedBox(height: 10),
          _StickerRow(),

          const SizedBox(height: 18),

          // Nearby Toggle
          _NearbyToggle(
            isOn: state.isNearbyOnly,
            onChanged: onNearbyChanged,
          ),
        ],
      ),
    );
  }
}

// ── Section Label ──────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF666680),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ── Background Bubbles ─────────────────────────────────────────
class _BackgroundBubbles extends StatelessWidget {
  const _BackgroundBubbles(
      {required this.selected, required this.onChanged});

  final PostBackground selected;
  final ValueChanged<PostBackground> onChanged;

  static const _solidColors = {
    PostBackground.saffron: Color(0xFFFF6B35),
    PostBackground.ocean: Color(0xFF0077B6),
    PostBackground.forest: Color(0xFF2D6A4F),
    PostBackground.sunset: Color(0xFFE63946),
    PostBackground.night: Color(0xFF1A1A2E),
    PostBackground.thambili: Color(0xFFF4A261),
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: PostBackground.values.map((bg) {
        final isSelected = bg == selected;
        return GestureDetector(
          onTap: () => onChanged(bg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 10),
            width: isSelected ? 38 : 34,
            height: isSelected ? 38 : 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _kBackgrounds[bg],
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: (_solidColors[bg] ?? Colors.white)
                      .withOpacity(0.5),
                  blurRadius: 12,
                )
              ]
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Font Style Row ─────────────────────────────────────────────
class _FontStyleRow extends StatelessWidget {
  const _FontStyleRow({required this.selected, required this.onChanged});
  final PostFontStyle selected;
  final ValueChanged<PostFontStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: PostFontStyle.values.map((fs) {
        final isSelected = fs == selected;
        return GestureDetector(
          onTap: () => onChanged(fs),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.15),
              ),
            ),
            child: Text(
              _kFontStyleLabels[fs]!,
              style: TextStyle(
                color: isSelected
                    ? Colors.black
                    : Colors.white.withOpacity(0.7),
                fontSize: 13,
                fontWeight: isSelected
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Sticker Row (Draggable) ────────────────────────────────────
class _StickerRow extends StatelessWidget {
  const _StickerRow();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _kStickerList.map((emoji) {
          return Draggable<String>(
            data: emoji,
            feedback: Text(emoji,
                style: const TextStyle(fontSize: 40)),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: Text(emoji,
                  style: const TextStyle(fontSize: 32)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(emoji,
                  style: const TextStyle(fontSize: 32)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Nearby Toggle ──────────────────────────────────────────────
class _NearbyToggle extends StatelessWidget {
  const _NearbyToggle({required this.isOn, required this.onChanged});
  final bool isOn;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📍 Nearby',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'ළඟපාතේ අයට විතරක් පෙන්වන්න',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: isOn,
          onChanged: onChanged,
          activeColor: const Color(0xFF4CAF50),
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: Colors.white.withOpacity(0.2),
        ),
      ],
    );
  }
}

// ── Glass Back Button ──────────────────────────────────────────
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.25),
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ── Animated Sticker (pop-in) ──────────────────────────────────
class _AnimatedSticker extends StatefulWidget {
  const _AnimatedSticker({required this.emoji});
  final String emoji;

  @override
  State<_AnimatedSticker> createState() => _AnimatedStickerState();
}

class _AnimatedStickerState extends State<_AnimatedSticker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Text(widget.emoji,
          style: const TextStyle(
              fontSize: 38,
              shadows: [
                Shadow(
                    color: Colors.black38,
                    blurRadius: 6,
                    offset: Offset(2, 3))
              ])),
    );
  }
}