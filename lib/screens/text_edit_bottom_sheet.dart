import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ENUMS & MODELS
// ═══════════════════════════════════════════════════════════════════════════════

enum TextAlignOption { left, center, right }
enum TextBgStyle    { none, solid, rounded }

/// Animation that plays when the text overlay is shown on media.
enum TextAnimation  {
  none, fadeIn, slideUp, slideLeft, slideRight, slideDown,
  typewriter, shake, glitch, bounce, pulse, spin, flip,
  zoom, zoomOut, swing, rubber, jello, tada, wobble,
  flash, heartbeat, wave, ripple, glow, fire, matrix,
  rain, snow, electric,
}

/// A visual preset (e.g. Gold, Neon, Retro).
class TextStylePreset {
  final String  name;
  final String  emoji;
  final Color   textColor;
  final Color   bgColor;
  final TextBgStyle bgStyle;
  final bool    neon;
  final bool    outline;
  final Color   outlineColor;
  final int     fontIndex;

  const TextStylePreset({
    required this.name,
    required this.emoji,
    required this.textColor,
    this.bgColor    = Colors.transparent,
    this.bgStyle    = TextBgStyle.none,
    this.neon       = false,
    this.outline    = false,
    this.outlineColor = Colors.black,
    this.fontIndex  = 0,
  });
}

class FontStyleOption {
  final String     name;
  final String     fontFamily;
  final FontWeight weight;
  final FontStyle  style;
  final bool       isBubble;

  const FontStyleOption({
    required this.name,
    this.fontFamily = '',
    this.weight     = FontWeight.normal,
    this.style      = FontStyle.normal,
    this.isBubble   = false,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// OVERLAY MODEL
// ═══════════════════════════════════════════════════════════════════════════════

class RichTextOverlay {
  String        text;
  double        x, y;
  Color         textColor;
  Color         bgColor;
  TextBgStyle   bgStyle;
  TextAlignOption align;
  double        fontSize;
  double        letterSpacing;
  double        lineHeight;
  FontWeight    fontWeight;
  FontStyle     fontStyle;
  String        fontFamily;
  bool          neon;
  bool          outline;
  Color         outlineColor;
  TextAnimation animation;
  double        startTime, endTime;

  RichTextOverlay({
    required this.text,
    this.x            = 80,
    this.y            = 200,
    this.textColor    = Colors.white,
    this.bgColor      = Colors.transparent,
    this.bgStyle      = TextBgStyle.none,
    this.align        = TextAlignOption.center,
    this.fontSize     = 28,
    this.letterSpacing = 0,
    this.lineHeight   = 1.3,
    this.fontWeight   = FontWeight.w400,
    this.fontStyle    = FontStyle.normal,
    this.fontFamily   = '',
    this.neon         = false,
    this.outline      = false,
    this.outlineColor = Colors.black,
    this.animation    = TextAnimation.none,
    this.startTime    = 0,
    this.endTime      = 10,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANIMATED TEXT WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

class AnimatedTextOverlayWidget extends StatefulWidget {
  final RichTextOverlay overlay;
  final double currentTime;

  const AnimatedTextOverlayWidget({
    super.key,
    required this.overlay,
    required this.currentTime,
  });

  @override
  State<AnimatedTextOverlayWidget> createState() =>
      _AnimatedTextOverlayWidgetState();
}

class _AnimatedTextOverlayWidgetState
    extends State<AnimatedTextOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  int _typewriterLen = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _slideAnim = Tween<Offset>(
      begin: _slideBegin(),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _startAnimation();
  }

  Offset _slideBegin() {
    switch (widget.overlay.animation) {
      case TextAnimation.slideLeft:  return const Offset(-0.6, 0);
      case TextAnimation.slideRight: return const Offset(0.6, 0);
      case TextAnimation.slideDown:  return const Offset(0, -0.4);
      default:                       return const Offset(0, 0.4);
    }
  }

  void _startAnimation() {
    switch (widget.overlay.animation) {
      case TextAnimation.fadeIn:
      case TextAnimation.zoom:
        _ctrl.forward();
        break;
      case TextAnimation.slideUp:
      case TextAnimation.slideLeft:
      case TextAnimation.slideRight:
      case TextAnimation.slideDown:
        _ctrl.forward();
        break;
      case TextAnimation.typewriter:
        _runTypewriter();
        break;
      case TextAnimation.shake:
      case TextAnimation.glitch:
      case TextAnimation.bounce:
      case TextAnimation.pulse:
      case TextAnimation.spin:
      case TextAnimation.flip:
      case TextAnimation.zoomOut:
      case TextAnimation.swing:
      case TextAnimation.rubber:
      case TextAnimation.jello:
      case TextAnimation.tada:
      case TextAnimation.wobble:
      case TextAnimation.flash:
      case TextAnimation.heartbeat:
      case TextAnimation.wave:
      case TextAnimation.ripple:
      case TextAnimation.glow:
      case TextAnimation.fire:
      case TextAnimation.matrix:
      case TextAnimation.rain:
      case TextAnimation.snow:
      case TextAnimation.electric:
        _ctrl.repeat(reverse: true);
        break;
      case TextAnimation.none:
        _ctrl.value = 1;
        break;
    }
  }

  Future<void> _runTypewriter() async {
    final full = widget.overlay.text;
    for (int i = 0; i <= full.length; i++) {
      await Future.delayed(const Duration(milliseconds: 55));
      if (!mounted) return;
      setState(() => _typewriterLen = i);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.overlay;

    if (widget.currentTime < o.startTime ||
        widget.currentTime > o.endTime) {
      return const SizedBox.shrink();
    }

    Widget textWidget = _buildStyledText(o);

    switch (o.animation) {
      case TextAnimation.fadeIn:
        textWidget = FadeTransition(opacity: _fadeAnim, child: textWidget);
        break;

      case TextAnimation.slideUp:
      case TextAnimation.slideLeft:
      case TextAnimation.slideRight:
      case TextAnimation.slideDown:
        textWidget = SlideTransition(
            position: _slideAnim,
            child: FadeTransition(opacity: _fadeAnim, child: textWidget));
        break;

      case TextAnimation.zoom:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) => Transform.scale(
            scale: 0.3 + (_ctrl.value * 0.7),
            child: FadeTransition(opacity: _fadeAnim, child: child),
          ),
          child: textWidget,
        );
        break;

      case TextAnimation.zoomOut:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) => Transform.scale(
            scale: 1.5 - (_ctrl.value * 0.5),
            child: child,
          ),
          child: textWidget,
        );
        break;

      case TextAnimation.shake:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final dx = math.sin(_ctrl.value * math.pi * 10) * 5;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: textWidget,
        );
        break;

      case TextAnimation.bounce:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final dy = -math.cos(math.sin(_ctrl.value * math.pi * 3)) * 12;
            return Transform.translate(offset: Offset(0, dy), child: child);
          },
          child: textWidget,
        );
        break;

      case TextAnimation.pulse:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) => Transform.scale(
            scale: 1.0 + (math.sin(_ctrl.value * math.pi * 2) * 0.08),
            child: child,
          ),
          child: textWidget,
        );
        break;

      case TextAnimation.spin:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) => Transform.rotate(
            angle: _ctrl.value * math.pi * 2,
            child: child,
          ),
          child: textWidget,
        );
        break;

      case TextAnimation.flip:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(_ctrl.value * math.pi),
            child: child,
          ),
          child: textWidget,
        );
        break;

      case TextAnimation.swing:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final angle = math.sin(_ctrl.value * math.pi * 3) * 0.15;
            return Transform.rotate(angle: angle, child: child);
          },
          child: textWidget,
        );
        break;

      case TextAnimation.rubber:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final sx = 1.0 + math.sin(_ctrl.value * math.pi * 2) * 0.25;
            final sy = 1.0 - math.sin(_ctrl.value * math.pi * 2) * 0.15;
            return Transform.scale(scaleX: sx, scaleY: sy, child: child);
          },
          child: textWidget,
        );
        break;

      case TextAnimation.jello:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final skew = math.sin(_ctrl.value * math.pi * 4) * 0.1;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewX(skew),
              child: child,
            );
          },
          child: textWidget,
        );
        break;

      case TextAnimation.tada:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final scale = 1.0 + math.sin(_ctrl.value * math.pi * 3) * 0.1;
            final angle = math.sin(_ctrl.value * math.pi * 6) * 0.08;
            return Transform.rotate(
              angle: angle,
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: textWidget,
        );
        break;

      case TextAnimation.wobble:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final dx = math.sin(_ctrl.value * math.pi * 4) * 8;
            final angle = math.sin(_ctrl.value * math.pi * 4) * 0.05;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.translationValues(dx, 0, 0)
                ..rotateZ(angle),
              child: child,
            );
          },
          child: textWidget,
        );
        break;

      case TextAnimation.flash:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final visible = (_ctrl.value * 6).floor() % 2 == 0;
            return Opacity(opacity: visible ? 1.0 : 0.0, child: child);
          },
          child: textWidget,
        );
        break;

      case TextAnimation.heartbeat:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            double scale = 1.0;
            final t = _ctrl.value;
            if (t < 0.14) scale = 1.0 + (t / 0.14) * 0.3;
            else if (t < 0.28) scale = 1.3 - ((t - 0.14) / 0.14) * 0.15;
            else if (t < 0.42) scale = 1.15 + ((t - 0.28) / 0.14) * 0.15;
            else if (t < 0.56) scale = 1.3 - ((t - 0.42) / 0.14) * 0.3;
            else scale = 1.0;
            return Transform.scale(scale: scale, child: child);
          },
          child: textWidget,
        );
        break;

      case TextAnimation.wave:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final dy = math.sin(_ctrl.value * math.pi * 3) * 6;
            return Transform.translate(offset: Offset(0, dy), child: child);
          },
          child: textWidget,
        );
        break;

      case TextAnimation.ripple:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final scale = 1.0 + math.sin(_ctrl.value * math.pi * 2) * 0.05;
            return Transform.scale(scale: scale, child: child);
          },
          child: textWidget,
        );
        break;

      case TextAnimation.glow:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final intensity = 0.5 + math.sin(_ctrl.value * math.pi * 2) * 0.5;
            return ColorFiltered(
              colorFilter: ColorFilter.matrix([
                1, 0, 0, 0, 20 * intensity,
                0, 1, 0, 0, 20 * intensity,
                0, 0, 1, 0, 20 * intensity,
                0, 0, 0, 1, 0,
              ]),
              child: child,
            );
          },
          child: textWidget,
        );
        break;

      case TextAnimation.fire:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final dy = math.sin(_ctrl.value * math.pi * 5) * 3;
            final scale = 1.0 + math.sin(_ctrl.value * math.pi * 3) * 0.03;
            return Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.translationValues(0, dy, 0)..scale(scale),
              child: child,
            );
          },
          child: textWidget,
        );
        break;

      case TextAnimation.matrix:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final offset = (_ctrl.value * 10).floor() % 2 == 0;
            return Transform.translate(
              offset: Offset(offset ? 2 : -2, 0),
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix([
                  0, 0, 0, 0, 0,
                  0, 1.5, 0, 0, 0,
                  0, 0, 0, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
                child: child,
              ),
            );
          },
          child: textWidget,
        );
        break;

      case TextAnimation.rain:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final dy = _ctrl.value * 20;
            return Transform.translate(
              offset: Offset(0, dy - 10),
              child: Opacity(opacity: 1 - (_ctrl.value * 0.3), child: child),
            );
          },
          child: textWidget,
        );
        break;

      case TextAnimation.snow:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final dx = math.sin(_ctrl.value * math.pi * 3) * 4;
            final dy = _ctrl.value * 8 - 4;
            return Transform.translate(
              offset: Offset(dx, dy),
              child: child,
            );
          },
          child: textWidget,
        );
        break;

      case TextAnimation.electric:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final rand = math.Random(((_ctrl.value * 100).toInt()));
            final dx = rand.nextDouble() * 6 - 3;
            final dy = rand.nextDouble() * 4 - 2;
            return Transform.translate(
              offset: Offset(dx, dy),
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix([
                  1, 0, 0, 0, _ctrl.value * 30,
                  0, 1, 0, 0, _ctrl.value * 10,
                  0, 0, 1.5, 0, _ctrl.value * 20,
                  0, 0, 0, 1, 0,
                ]),
                child: child,
              ),
            );
          },
          child: textWidget,
        );
        break;

      case TextAnimation.glitch:
        textWidget = AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final rand = math.Random();
            final glitching = _ctrl.value > 0.6;
            return glitching
                ? Transform.translate(
                offset: Offset(rand.nextDouble() * 8 - 4, 0),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    1.5, 0, 0, 0, -20,
                    0, 0.8, 0, 0, 0,
                    0, 0, 1.5, 0, 0,
                    0, 0, 0, 1, 0,
                  ]),
                  child: child,
                ))
                : child!;
          },
          child: textWidget,
        );
        break;

      case TextAnimation.typewriter:
        final display = o.text.substring(
            0, _typewriterLen.clamp(0, o.text.length));
        textWidget = _buildStyledText(o, overrideText: display);
        break;

      default:
        break;
    }

    return textWidget;
  }

  Widget _buildStyledText(RichTextOverlay o, {String? overrideText}) {
    final displayText = overrideText ?? o.text;

    final List<Shadow> shadows = [];
    if (o.neon) {
      shadows.addAll([
        Shadow(color: o.textColor.withOpacity(0.9), blurRadius: 12),
        Shadow(color: o.textColor.withOpacity(0.6), blurRadius: 24),
        Shadow(color: o.textColor.withOpacity(0.3), blurRadius: 48),
      ]);
    } else if (o.outline) {
      for (final dx in [-2.0, 2.0]) {
        for (final dy in [-2.0, 2.0]) {
          shadows.add(Shadow(
              color: o.outlineColor, offset: Offset(dx, dy), blurRadius: 0));
        }
      }
    } else {
      shadows.add(Shadow(
          color: Colors.black.withOpacity(0.7),
          offset: const Offset(1.5, 1.5),
          blurRadius: 3));
    }

    final textStyle = TextStyle(
      color: o.textColor,
      fontSize: o.fontSize,
      fontWeight: o.fontWeight,
      fontStyle: o.fontStyle,
      fontFamily: o.fontFamily.isEmpty ? null : o.fontFamily,
      letterSpacing: o.letterSpacing,
      height: o.lineHeight,
      shadows: shadows,
    );

    Widget core = Text(
      displayText,
      style: textStyle,
      textAlign: o.align == TextAlignOption.left
          ? TextAlign.left
          : o.align == TextAlignOption.right
          ? TextAlign.right
          : TextAlign.center,
    );

    if (o.bgStyle != TextBgStyle.none) {
      core = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: o.bgColor == Colors.transparent ? Colors.black54 : o.bgColor,
          borderRadius:
          BorderRadius.circular(o.bgStyle == TextBgStyle.rounded ? 28 : 6),
        ),
        child: core,
      );
    }

    return core;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEXT EDIT BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class TextEditBottomSheet extends StatefulWidget {
  final void Function(RichTextOverlay overlay) onDone;
  final double mediaDuration;

  const TextEditBottomSheet({
    super.key,
    required this.onDone,
    this.mediaDuration = 10.0,
  });

  @override
  State<TextEditBottomSheet> createState() => _TextEditBottomSheetState();
}

class _TextEditBottomSheetState extends State<TextEditBottomSheet>
    with SingleTickerProviderStateMixin {

  // ── 50 Font catalogue ──────────────────────────────────────────────────────
  static const List<FontStyleOption> _fontStyles = [
    // ── MODERN / SANS ─────────────────────────────────────────
    FontStyleOption(name: 'Modern',          fontFamily: '',               weight: FontWeight.w400),
    FontStyleOption(name: 'Modern Bold',     fontFamily: '',               weight: FontWeight.w800),
    FontStyleOption(name: 'Thin',            fontFamily: '',               weight: FontWeight.w100),
    FontStyleOption(name: 'Light',           fontFamily: '',               weight: FontWeight.w300),
    FontStyleOption(name: 'Medium',          fontFamily: '',               weight: FontWeight.w500),
    FontStyleOption(name: 'SemiBold',        fontFamily: '',               weight: FontWeight.w600),
    FontStyleOption(name: 'Heavy',           fontFamily: '',               weight: FontWeight.w900),
    FontStyleOption(name: 'Italic',          fontFamily: '',               weight: FontWeight.w400, style: FontStyle.italic),
    FontStyleOption(name: 'Bold Italic',     fontFamily: '',               weight: FontWeight.w700, style: FontStyle.italic),
    FontStyleOption(name: 'Light Italic',    fontFamily: '',               weight: FontWeight.w300, style: FontStyle.italic),

    // ── SERIF / CLASSIC ───────────────────────────────────────
    FontStyleOption(name: 'Classic',         fontFamily: 'serif',          weight: FontWeight.w700),
    FontStyleOption(name: 'Classic Light',   fontFamily: 'serif',          weight: FontWeight.w300),
    FontStyleOption(name: 'Serif Italic',    fontFamily: 'serif',          weight: FontWeight.w400, style: FontStyle.italic),
    FontStyleOption(name: 'Serif Bold',      fontFamily: 'serif',          weight: FontWeight.w800),
    FontStyleOption(name: 'Serif Thin',      fontFamily: 'serif',          weight: FontWeight.w100),

    // ── MONOSPACE / CODE ──────────────────────────────────────
    FontStyleOption(name: 'Editor',          fontFamily: 'monospace',      weight: FontWeight.w400),
    FontStyleOption(name: 'Code Bold',       fontFamily: 'monospace',      weight: FontWeight.w700),
    FontStyleOption(name: 'Terminal',        fontFamily: 'monospace',      weight: FontWeight.w300),

    // ── POSTER / DISPLAY ──────────────────────────────────────
    FontStyleOption(name: 'Poster',          fontFamily: '',               weight: FontWeight.w900),
    FontStyleOption(name: 'Bubble',          fontFamily: '',               weight: FontWeight.w700, isBubble: true),

    // ── SIGNATURE / SCRIPT ────────────────────────────────────
    FontStyleOption(name: 'Signature',       fontFamily: '',               weight: FontWeight.w400, style: FontStyle.italic),
    FontStyleOption(name: 'Cursive',         fontFamily: 'cursive',        weight: FontWeight.w400),
    FontStyleOption(name: 'Cursive Bold',    fontFamily: 'cursive',        weight: FontWeight.w700),

    // ── GOOGLE FONTS (bundled in most Flutter apps) ───────────
    FontStyleOption(name: 'Roboto',          fontFamily: 'Roboto',         weight: FontWeight.w400),
    FontStyleOption(name: 'Roboto Bold',     fontFamily: 'Roboto',         weight: FontWeight.w700),
    FontStyleOption(name: 'Roboto Black',    fontFamily: 'Roboto',         weight: FontWeight.w900),
    FontStyleOption(name: 'Roboto Thin',     fontFamily: 'Roboto',         weight: FontWeight.w100),
    FontStyleOption(name: 'Roboto Italic',   fontFamily: 'Roboto',         weight: FontWeight.w400, style: FontStyle.italic),
    FontStyleOption(name: 'Open Sans',       fontFamily: 'OpenSans',       weight: FontWeight.w400),
    FontStyleOption(name: 'Open Sans Bold',  fontFamily: 'OpenSans',       weight: FontWeight.w700),
    FontStyleOption(name: 'Lato',            fontFamily: 'Lato',           weight: FontWeight.w400),
    FontStyleOption(name: 'Lato Bold',       fontFamily: 'Lato',           weight: FontWeight.w700),
    FontStyleOption(name: 'Lato Black',      fontFamily: 'Lato',           weight: FontWeight.w900),
    FontStyleOption(name: 'Montserrat',      fontFamily: 'Montserrat',     weight: FontWeight.w600),
    FontStyleOption(name: 'Montserrat Bold', fontFamily: 'Montserrat',     weight: FontWeight.w800),
    FontStyleOption(name: 'Raleway',         fontFamily: 'Raleway',        weight: FontWeight.w400),
    FontStyleOption(name: 'Raleway Bold',    fontFamily: 'Raleway',        weight: FontWeight.w700),
    FontStyleOption(name: 'Nunito',          fontFamily: 'Nunito',         weight: FontWeight.w400),
    FontStyleOption(name: 'Nunito Bold',     fontFamily: 'Nunito',         weight: FontWeight.w800),
    FontStyleOption(name: 'Poppins',         fontFamily: 'Poppins',        weight: FontWeight.w500),
    FontStyleOption(name: 'Poppins Bold',    fontFamily: 'Poppins',        weight: FontWeight.w700),
    FontStyleOption(name: 'Inter',           fontFamily: 'Inter',          weight: FontWeight.w400),
    FontStyleOption(name: 'Inter Bold',      fontFamily: 'Inter',          weight: FontWeight.w700),
    FontStyleOption(name: 'Oswald',          fontFamily: 'Oswald',         weight: FontWeight.w500),
    FontStyleOption(name: 'Playfair',        fontFamily: 'PlayfairDisplay', weight: FontWeight.w700),
    FontStyleOption(name: 'Dancing Script',  fontFamily: 'DancingScript',  weight: FontWeight.w700),
    FontStyleOption(name: 'Pacifico',        fontFamily: 'Pacifico',       weight: FontWeight.w400),
    FontStyleOption(name: 'Bebas Neue',      fontFamily: 'BebasNeue',      weight: FontWeight.w400),

    // ── SINHALA ───────────────────────────────────────────────
    FontStyleOption(name: 'සිංහල',           fontFamily: 'NotoSansSinhala', weight: FontWeight.w400),
    FontStyleOption(name: 'සිංහල Bold',      fontFamily: 'NotoSansSinhala', weight: FontWeight.w700),
  ];

  // ── Presets ────────────────────────────────────────────────────────────────
  static const List<TextStylePreset> _presets = [
    TextStylePreset(
      name: 'Gold', emoji: '✨',
      textColor: Color(0xFFFFD700),
      neon: true, outlineColor: Color(0xFF8B6914),
    ),
    TextStylePreset(
      name: 'Neon', emoji: '💜',
      textColor: Color(0xFFEA00FF),
      neon: true, fontIndex: 1,
    ),
    TextStylePreset(
      name: 'Retro', emoji: '📺',
      textColor: Color(0xFFFF6B35),
      bgColor: Color(0xFF1A1A2E),
      bgStyle: TextBgStyle.rounded, fontIndex: 18,
    ),
    TextStylePreset(
      name: 'News', emoji: '📰',
      textColor: Colors.white,
      bgColor: Color(0xFFCC0000),
      bgStyle: TextBgStyle.solid, fontIndex: 10,
    ),
    TextStylePreset(
      name: 'Ice', emoji: '🧊',
      textColor: Color(0xFF87CEEB),
      neon: true, fontIndex: 11,
    ),
    TextStylePreset(
      name: 'Shadow', emoji: '🌑',
      textColor: Colors.white,
      outline: true, outlineColor: Colors.black, fontIndex: 1,
    ),
    TextStylePreset(
      name: 'Candy', emoji: '🍭',
      textColor: Color(0xFFFF69B4),
      bgColor: Color(0xFFFFF0F5),
      bgStyle: TextBgStyle.rounded, fontIndex: 19,
    ),
    TextStylePreset(
      name: 'Matrix', emoji: '💻',
      textColor: Color(0xFF00FF41),
      neon: true, bgColor: Colors.black,
      bgStyle: TextBgStyle.solid, fontIndex: 15,
    ),
  ];

  // ── Colour palettes ────────────────────────────────────────────────────────
  static const List<Color> _textColors = [
    Colors.white, Colors.black, Color(0xFFFF4444), Colors.orange,
    Colors.yellow, Color(0xFF00E676), Colors.cyan, Color(0xFF448AFF),
    Color(0xFFAA00FF), Color(0xFFFF80AB), Color(0xFFFFD700), Color(0xFF00FF7F),
  ];
  static const List<Color> _bgColors = [
    Colors.transparent, Colors.black, Colors.white, Color(0xFFFF4444),
    Colors.orange, Colors.yellow, Color(0xFF00E676), Color(0xFF448AFF),
    Color(0xFFAA00FF), Color(0xFFFF80AB), Color(0xFF212121), Color(0xFF1565C0),
  ];

  // ── 30 Animation options ───────────────────────────────────────────────────
  static const List<({TextAnimation anim, IconData icon, String label})> _animOptions = [
    (anim: TextAnimation.none,       icon: Icons.block,               label: 'None'),
    (anim: TextAnimation.fadeIn,     icon: Icons.opacity,             label: 'Fade In'),
    (anim: TextAnimation.slideUp,    icon: Icons.arrow_upward,        label: 'Slide Up'),
    (anim: TextAnimation.slideDown,  icon: Icons.arrow_downward,      label: 'Slide Down'),
    (anim: TextAnimation.slideLeft,  icon: Icons.arrow_back,          label: 'Slide Left'),
    (anim: TextAnimation.slideRight, icon: Icons.arrow_forward,       label: 'Slide Right'),
    (anim: TextAnimation.typewriter, icon: Icons.keyboard,            label: 'Typewriter'),
    (anim: TextAnimation.shake,      icon: Icons.vibration,           label: 'Shake'),
    (anim: TextAnimation.bounce,     icon: Icons.sports_basketball,   label: 'Bounce'),
    (anim: TextAnimation.pulse,      icon: Icons.favorite,            label: 'Pulse'),
    (anim: TextAnimation.spin,       icon: Icons.rotate_right,        label: 'Spin'),
    (anim: TextAnimation.flip,       icon: Icons.flip,                label: 'Flip'),
    (anim: TextAnimation.zoom,       icon: Icons.zoom_in,             label: 'Zoom In'),
    (anim: TextAnimation.zoomOut,    icon: Icons.zoom_out,            label: 'Zoom Out'),
    (anim: TextAnimation.swing,      icon: Icons.directions_walk,     label: 'Swing'),
    (anim: TextAnimation.rubber,     icon: Icons.expand,              label: 'Rubber'),
    (anim: TextAnimation.jello,      icon: Icons.waves,               label: 'Jello'),
    (anim: TextAnimation.tada,       icon: Icons.celebration,         label: 'Tada'),
    (anim: TextAnimation.wobble,     icon: Icons.shuffle,             label: 'Wobble'),
    (anim: TextAnimation.flash,      icon: Icons.flash_on,            label: 'Flash'),
    (anim: TextAnimation.heartbeat,  icon: Icons.monitor_heart,       label: 'Heartbeat'),
    (anim: TextAnimation.wave,       icon: Icons.water,               label: 'Wave'),
    (anim: TextAnimation.ripple,     icon: Icons.circle,              label: 'Ripple'),
    (anim: TextAnimation.glow,       icon: Icons.light_mode,          label: 'Glow'),
    (anim: TextAnimation.fire,       icon: Icons.local_fire_department, label: 'Fire'),
    (anim: TextAnimation.matrix,     icon: Icons.grid_on,             label: 'Matrix'),
    (anim: TextAnimation.glitch,     icon: Icons.blur_on,             label: 'Glitch'),
    (anim: TextAnimation.rain,       icon: Icons.water_drop,          label: 'Rain'),
    (anim: TextAnimation.snow,       icon: Icons.ac_unit,             label: 'Snow'),
    (anim: TextAnimation.electric,   icon: Icons.electric_bolt,       label: 'Electric'),
  ];

  // ── State ──────────────────────────────────────────────────────────────────
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode             _focusNode = FocusNode();

  int             _fontIndex     = 0;
  Color           _textColor     = Colors.white;
  Color           _bgColor       = Colors.transparent;
  TextBgStyle     _bgStyle       = TextBgStyle.none;
  TextAlignOption _align         = TextAlignOption.center;
  double          _fontSize      = 28;
  double          _letterSpacing = 0;
  double          _lineHeight    = 1.3;
  bool            _neon          = false;
  bool            _outline       = false;
  Color           _outlineColor  = Colors.black;
  TextAnimation   _animation     = TextAnimation.none;
  double          _startTime     = 0;
  late double     _endTime;
  int             _activeTab     = 0;

  // ── Animation preview controller ──────────────────────────────────────────
  late AnimationController _previewCtrl;

  @override
  void initState() {
    super.initState();
    _endTime = widget.mediaDuration;
    _focusNode.addListener(() => setState(() {}));

    _previewCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    _previewCtrl.dispose();
    super.dispose();
  }

  // ── Done ───────────────────────────────────────────────────────────────────
  void _handleDone() {
    if (_textCtrl.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }
    final font = _fontStyles[_fontIndex];
    widget.onDone(RichTextOverlay(
      text:          _textCtrl.text.trim(),
      textColor:     _textColor,
      bgColor:       _bgColor,
      bgStyle:       _bgStyle,
      align:         _align,
      fontSize:      _fontSize,
      letterSpacing: _letterSpacing,
      lineHeight:    _lineHeight,
      fontWeight:    font.weight,
      fontStyle:     font.style,
      fontFamily:    font.fontFamily,
      neon:          _neon,
      outline:       _outline,
      outlineColor:  _outlineColor,
      animation:     _animation,
      startTime:     _startTime,
      endTime:       _endTime,
    ));
    Navigator.pop(context);
  }

  // ── Apply preset ───────────────────────────────────────────────────────────
  void _applyPreset(TextStylePreset p) {
    HapticFeedback.lightImpact();
    setState(() {
      _textColor    = p.textColor;
      _bgColor      = p.bgColor;
      _bgStyle      = p.bgStyle;
      _neon         = p.neon;
      _outline      = p.outline;
      _outlineColor = p.outlineColor;
      _fontIndex    = p.fontIndex.clamp(0, _fontStyles.length - 1);
    });
  }

  TextAlign get _textAlignValue {
    switch (_align) {
      case TextAlignOption.left:   return TextAlign.left;
      case TextAlignOption.right:  return TextAlign.right;
      case TextAlignOption.center: return TextAlign.center;
    }
  }

  // ── Live text style ────────────────────────────────────────────────────────
  TextStyle get _liveStyle {
    final font = _fontStyles[_fontIndex];
    final List<Shadow> shadows = [];
    if (_neon) {
      shadows.addAll([
        Shadow(color: _textColor.withOpacity(0.9), blurRadius: 10),
        Shadow(color: _textColor.withOpacity(0.5), blurRadius: 20),
      ]);
    } else if (_outline) {
      for (final d in [-2.0, 2.0]) {
        shadows.add(Shadow(color: _outlineColor, offset: Offset(d, d), blurRadius: 0));
        shadows.add(Shadow(color: _outlineColor, offset: Offset(d, -d), blurRadius: 0));
      }
    } else {
      shadows.add(Shadow(color: Colors.black.withOpacity(0.6),
          offset: const Offset(1, 1), blurRadius: 3));
    }
    return TextStyle(
      color:         _textColor,
      fontSize:      _fontSize.clamp(14.0, 36.0),
      fontWeight:    font.weight,
      fontStyle:     font.style,
      fontFamily:    font.fontFamily.isEmpty ? null : font.fontFamily,
      letterSpacing: _letterSpacing,
      height:        _lineHeight,
      shadows:       shadows,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final bottomInset  = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom   = MediaQuery.of(context).padding.bottom;
    final keyboardOpen = bottomInset > 50;

    return AnimatedPadding(
      padding:  EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 200),
      curve:    Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.93),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            _buildTopBar(),
            _buildInput(),
            if (!keyboardOpen) ...[
              _buildPresetRow(),
              _buildTabRow(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _buildTabContent(),
              ),
            ],
            if (keyboardOpen) _buildHideKeyboard(),
            SizedBox(height: keyboardOpen ? 4 : safeBottom + 8),
          ],
        ),
      ),
    );
  }

  // ── Drag handle ────────────────────────────────────────────────────────────
  Widget _buildDragHandle() => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 6),
    child: Container(
      width: 36, height: 4,
      decoration: BoxDecoration(
          color: Colors.white30, borderRadius: BorderRadius.circular(2)),
    ),
  );

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: const Icon(Icons.close, color: Colors.white, size: 24),
      ),
      const SizedBox(width: 6),
      const Icon(Icons.format_size, color: Colors.white38, size: 15),
      Expanded(
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape:  const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor:   Colors.white,
            inactiveTrackColor: Colors.white30,
            thumbColor:         Colors.white,
          ),
          child: Slider(
            value:    _fontSize,
            min: 14, max: 72,
            onChanged: (v) => setState(() => _fontSize = v),
          ),
        ),
      ),
      // Align buttons
      _alignBtn(TextAlignOption.left,   Icons.format_align_left),
      _alignBtn(TextAlignOption.center, Icons.format_align_center),
      _alignBtn(TextAlignOption.right,  Icons.format_align_right),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _handleDone,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: const Text('Done',
              style: TextStyle(color: Colors.black,
                  fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ),
    ]),
  );

  Widget _alignBtn(TextAlignOption opt, IconData icon) => GestureDetector(
    onTap: () => setState(() => _align = opt),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(icon,
          color: _align == opt ? Colors.white : Colors.white30, size: 18),
    ),
  );

  // ── Live styled input ──────────────────────────────────────────────────────
  Widget _buildInput() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _bgStyle == TextBgStyle.none
            ? Colors.white.withOpacity(0.07)
            : (_bgColor == Colors.transparent ? Colors.black54 : _bgColor),
        borderRadius:
        BorderRadius.circular(_bgStyle == TextBgStyle.rounded ? 14 : 8),
        border: _bgStyle == TextBgStyle.none
            ? Border.all(color: Colors.white12) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: TextField(
        controller:  _textCtrl,
        focusNode:   _focusNode,
        autofocus:   true,
        maxLines:    null,
        keyboardType: TextInputType.multiline,
        style:       _liveStyle,
        textAlign:   _textAlignValue,
        decoration: InputDecoration(
          hintText:  'ටෙක්ස්ට් ටයිප් කරන්න...',
          hintStyle: TextStyle(color: _textColor.withOpacity(0.35), fontSize: 16),
          border:    InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        ),
        onChanged: (_) => setState(() {}),
      ),
    ),
  );

  // ── Preset row ─────────────────────────────────────────────────────────────
  Widget _buildPresetRow() => SizedBox(
    height: 54,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      itemCount: _presets.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final p = _presets[i];
        return GestureDetector(
          onTap: () => _applyPreset(p),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: p.bgStyle != TextBgStyle.none &&
                  p.bgColor != Colors.transparent
                  ? p.bgColor.withOpacity(0.85)
                  : Colors.white10,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(p.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
              Text(p.name,
                  style: TextStyle(
                      color: p.textColor, fontSize: 12,
                      fontWeight: FontWeight.w600,
                      shadows: p.neon
                          ? [Shadow(color: p.textColor.withOpacity(0.9), blurRadius: 8)]
                          : null)),
            ]),
          ),
        );
      },
    ),
  );

  // ── Tab row ────────────────────────────────────────────────────────────────
  static const _tabs = [
    (Icons.font_download_outlined,  'Font'),
    (Icons.palette_outlined,        'Color'),
    (Icons.format_color_fill,       'BG'),
    (Icons.auto_fix_high,           'Effects'),
    (Icons.animation,               'Anim'),
    (Icons.space_bar,               'Spacing'),
    (Icons.timer_outlined,          'Time'),
  ];

  Widget _buildTabRow() => Container(
    color: Colors.white.withOpacity(0.05),
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_tabs.length, (i) {
        final isActive = _activeTab == i;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _activeTab = i);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_tabs[i].$1,
                  color: isActive ? Colors.white : Colors.white70, size: 20),
              const SizedBox(height: 2),
              Text(_tabs[i].$2,
                  style: TextStyle(
                      color: isActive ? Colors.white : Colors.white38,
                      fontSize: 9)),
              if (isActive)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 14, height: 2,
                  decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(1)),
                ),
            ],
          ),
        );
      }),
    ),
  );

  Widget _buildTabContent() {
    switch (_activeTab) {
      case 0: return _buildFontTab();
      case 1: return _buildColorTab();
      case 2: return _buildBgTab();
      case 3: return _buildEffectsTab();
      case 4: return _buildAnimTab();
      case 5: return _buildSpacingTab();
      case 6: return _buildTimeTab();
      default: return _buildFontTab();
    }
  }

  // ── Font tab (50 fonts) ────────────────────────────────────────────────────
  Widget _buildFontTab() {
    return SizedBox(
      key: const ValueKey('font'),
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        itemCount: _fontStyles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final font  = _fontStyles[i];
          final isSel = _fontIndex == i;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _fontIndex = i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSel
                    ? Colors.white.withOpacity(0.18)
                    : Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: isSel
                    ? Border.all(color: Colors.white, width: 1.5)
                    : Border.all(color: Colors.white12),
              ),
              alignment: Alignment.center,
              child: Text(
                font.name,
                style: TextStyle(
                  color:      Colors.white,
                  fontWeight: font.weight,
                  fontStyle:  font.style,
                  fontFamily: font.fontFamily.isEmpty ? null : font.fontFamily,
                  fontSize:   15,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Color tab ──────────────────────────────────────────────────────────────
  Widget _buildColorTab() {
    return SizedBox(
      key: const ValueKey('color'),
      height: 78,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: _textColors.map((c) {
          final isSel = _textColor == c;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _textColor = c);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              margin: const EdgeInsets.only(right: 10),
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: c, shape: BoxShape.circle,
                border: Border.all(
                    color: isSel ? Colors.white : Colors.white30,
                    width: isSel ? 3 : 1.5),
                boxShadow: isSel
                    ? [BoxShadow(color: c.withOpacity(0.55), blurRadius: 8)]
                    : null,
              ),
              child: isSel
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── BG tab ─────────────────────────────────────────────────────────────────
  Widget _buildBgTab() => SizedBox(
    key: const ValueKey('bg'),
    height: 110,
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        child: Row(children: [
          _bgChip(TextBgStyle.none,    'None'),
          const SizedBox(width: 8),
          _bgChip(TextBgStyle.solid,   'Solid'),
          const SizedBox(width: 8),
          _bgChip(TextBgStyle.rounded, 'Rounded'),
        ]),
      ),
      Expanded(
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          children: _bgColors.map((c) {
            final isSel = _bgColor == c;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _bgColor = c;
                  if (c == Colors.transparent) {
                    _bgStyle = TextBgStyle.none;
                  } else if (_bgStyle == TextBgStyle.none) {
                    _bgStyle = TextBgStyle.rounded;
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                margin: const EdgeInsets.only(right: 10),
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: c == Colors.transparent ? null : c,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: isSel ? Colors.white : Colors.white30,
                      width: isSel ? 3 : 1.5),
                ),
                child: c == Colors.transparent
                    ? const Icon(Icons.block, color: Colors.white30, size: 18)
                    : (isSel
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null),
              ),
            );
          }).toList(),
        ),
      ),
    ]),
  );

  Widget _bgChip(TextBgStyle style, String label) {
    final isSel = _bgStyle == style;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _bgStyle = style);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSel ? Colors.white : Colors.white12,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSel ? Colors.black : Colors.white,
                fontSize: 12, fontWeight: FontWeight.w500)),
      ),
    );
  }

  // ── Effects tab ────────────────────────────────────────────────────────────
  Widget _buildEffectsTab() => SizedBox(
    key: const ValueKey('effects'),
    height: 120,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _effectRow(
          icon: Icons.blur_on,
          label: '✨ Neon Glow',
          subtitle: 'අකුරු වටේ ආලෝකය',
          value: _neon,
          onChanged: (v) => setState(() { _neon = v; if (v) _outline = false; }),
        ),
        const SizedBox(height: 8),
        _effectRow(
          icon: Icons.border_color,
          label: '⬜ Outline / Stroke',
          subtitle: 'අකුර වටේ බෝඩරය',
          value: _outline,
          onChanged: (v) => setState(() { _outline = v; if (v) _neon = false; }),
        ),
        if (_outline) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Text('Outline Color: ',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            ...[Colors.black, Colors.white, Color(0xFFFF4444), Color(0xFF448AFF)]
                .map((c) {
              final isSel = _outlineColor == c;
              return GestureDetector(
                onTap: () => setState(() => _outlineColor = c),
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: c, shape: BoxShape.circle,
                    border: Border.all(
                        color: isSel ? Colors.white : Colors.white30,
                        width: isSel ? 2.5 : 1),
                  ),
                ),
              );
            }),
          ]),
        ],
      ]),
    ),
  );

  Widget _effectRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Row(children: [
    Icon(icon, color: Colors.white54, size: 18),
    const SizedBox(width: 10),
    Expanded(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    )),
    Switch(
      value: value, onChanged: onChanged,
      activeColor: Colors.white,
      activeTrackColor: Colors.blue,
      inactiveTrackColor: Colors.white12,
      inactiveThumbColor: Colors.white38,
    ),
  ]);

  // ── Animation tab (30 animations) ──────────────────────────────────────────
  Widget _buildAnimTab() => SizedBox(
    key: const ValueKey('anim'),
    height: 110,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Animation: ${_animOptions.firstWhere((a) => a.anim == _animation).label}',
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            itemCount: _animOptions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final a     = _animOptions[i];
              final isSel = _animation == a.anim;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _animation = a.anim);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSel
                        ? const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)])
                        : null,
                    color: isSel ? null : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: isSel
                        ? Border.all(color: Colors.white60, width: 1.5)
                        : Border.all(color: Colors.white12),
                    boxShadow: isSel
                        ? [const BoxShadow(
                        color: Color(0x556C63FF), blurRadius: 8)]
                        : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(a.icon,
                        color: isSel ? Colors.white : Colors.white60, size: 16),
                    const SizedBox(width: 6),
                    Text(a.label,
                        style: TextStyle(
                            color: isSel ? Colors.white : Colors.white60,
                            fontSize: 12,
                            fontWeight: isSel
                                ? FontWeight.w600
                                : FontWeight.normal)),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  // ── Spacing tab ────────────────────────────────────────────────────────────
  Widget _buildSpacingTab() => Container(
    key: const ValueKey('spacing'),
    height: 110,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Column(children: [
      Row(children: [
        const Icon(Icons.space_bar, color: Colors.white54, size: 16),
        const SizedBox(width: 8),
        const Text('Letter Spacing',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        const Spacer(),
        Text(_letterSpacing.toStringAsFixed(1),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2,
          activeTrackColor: Colors.white,
          inactiveTrackColor: Colors.white24,
          thumbColor: Colors.white,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
        ),
        child: Slider(
          value: _letterSpacing,
          min: -4, max: 20,
          onChanged: (v) => setState(() => _letterSpacing = v),
        ),
      ),
      Row(children: [
        const Icon(Icons.format_line_spacing, color: Colors.white54, size: 16),
        const SizedBox(width: 8),
        const Text('Line Height',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        const Spacer(),
        Text(_lineHeight.toStringAsFixed(1),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2,
          activeTrackColor: Colors.white,
          inactiveTrackColor: Colors.white24,
          thumbColor: Colors.white,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
        ),
        child: Slider(
          value: _lineHeight,
          min: 0.8, max: 3.0,
          onChanged: (v) => setState(() => _lineHeight = v),
        ),
      ),
    ]),
  );

  // ── Time tab (FIXED — proper RangeSlider with correct max) ────────────────
  Widget _buildTimeTab() {
    final duration = widget.mediaDuration > 0 ? widget.mediaDuration : 30.0;
    // Clamp values to valid range
    final start = _startTime.clamp(0.0, duration - 0.5);
    final end   = _endTime.clamp(start + 0.5, duration);

    return Container(
      key: const ValueKey('time'),
      height: 110,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(children: [
        // ── Header row ──
        Row(children: [
          const Icon(Icons.timer, color: Colors.white54, size: 16),
          const SizedBox(width: 6),
          const Text('Show Duration',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${start.toInt()}s → ${end.toInt()}s  (${(end - start).toInt()}s)',
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
        const SizedBox(height: 6),

        // ── RangeSlider ──
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor:   const Color(0xFF6C63FF),
            inactiveTrackColor: Colors.white24,
            thumbColor:         Colors.white,
            overlayColor:       Colors.white24,
            trackHeight:        3,
            rangeThumbShape:    const RoundRangeSliderThumbShape(
                enabledThumbRadius: 8),
          ),
          child: RangeSlider(
            values: RangeValues(start, end),
            min:    0,
            max:    duration,
            divisions: duration.toInt().clamp(1, 300),
            labels: RangeLabels('${start.toInt()}s', '${end.toInt()}s'),
            onChanged: (v) => setState(() {
              _startTime = v.start;
              _endTime   = v.end;
            }),
          ),
        ),

        // ── Quick-set buttons ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _timeChip('Full', () => setState(() {
              _startTime = 0;
              _endTime   = duration;
            })),
            _timeChip('First half', () => setState(() {
              _startTime = 0;
              _endTime   = duration / 2;
            })),
            _timeChip('Second half', () => setState(() {
              _startTime = duration / 2;
              _endTime   = duration;
            })),
          ],
        ),
      ]),
    );
  }

  Widget _timeChip(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white60, fontSize: 10)),
    ),
  );

  // ── Hide keyboard hint ─────────────────────────────────────────────────────
  Widget _buildHideKeyboard() => GestureDetector(
    onTap: () => _focusNode.unfocus(),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.keyboard_hide, color: Colors.white38, size: 16),
          SizedBox(width: 6),
          Text('Keyboard වහන්න',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    ),
  );
}