import 'dart:math';
import 'package:flutter/material.dart';

// ── Effect Model ─────────────────────────────────────────────────────────────

class EffectLayer {
  final String id;
  final String effectKey;
  double intensity;
  double startSec;
  double endSec;

  EffectLayer({
    required this.id,
    required this.effectKey,
    this.intensity = 0.5,
    this.startSec = 0.0,
    this.endSec = 10.0,
  });
}

// ── Effect Definition ─────────────────────────────────────────────────────────

class EffectDef {
  final String key;
  final String label;
  final IconData icon;
  final Color accentColor;
  final String category;

  const EffectDef({
    required this.key,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.category,
  });
}

const List<EffectDef> kAllEffects = [
  // ── ⚡ Visual ──
  EffectDef(key: 'glitch',      label: 'Glitch',       icon: Icons.error_outline,       accentColor: Color(0xFFFF4458), category: '⚡ Visual'),
  EffectDef(key: 'rgb',         label: 'RGB Split',    icon: Icons.format_color_fill,   accentColor: Color(0xFF9C27B0), category: '⚡ Visual'),
  EffectDef(key: 'mirror',      label: 'Mirror',       icon: Icons.flip,                accentColor: Color(0xFF2196F3), category: '⚡ Visual'),
  EffectDef(key: 'pixelate',    label: 'Pixelate',     icon: Icons.grid_on,             accentColor: Color(0xFF00BCD4), category: '⚡ Visual'),
  EffectDef(key: 'shake',       label: 'Shake',        icon: Icons.shutter_speed,       accentColor: Color(0xFFFF9800), category: '⚡ Visual'),
  EffectDef(key: 'zoom_pulse',  label: 'Zoom Pulse',   icon: Icons.zoom_in,             accentColor: Color(0xFFE91E63), category: '⚡ Visual'),
  EffectDef(key: 'color_shift', label: 'Color Shift',  icon: Icons.color_lens,          accentColor: Color(0xFF00E5FF), category: '⚡ Visual'),
  EffectDef(key: 'invert',      label: 'Invert',       icon: Icons.invert_colors,       accentColor: Color(0xFF607D8B), category: '⚡ Visual'),
  EffectDef(key: 'scanline',    label: 'Scanline',     icon: Icons.format_strikethrough,accentColor: Color(0xFF78909C), category: '⚡ Visual'),
  EffectDef(key: 'edge_glow',   label: 'Edge Glow',    icon: Icons.flare,               accentColor: Color(0xFFFF6D00), category: '⚡ Visual'),
  EffectDef(key: 'kaleidoscope',label: 'Kaleidoscope', icon: Icons.blur_circular,       accentColor: Color(0xFFAA00FF), category: '⚡ Visual'),
  EffectDef(key: 'fisheye',     label: 'Fisheye',      icon: Icons.lens,                accentColor: Color(0xFF0091EA), category: '⚡ Visual'),

  // ── 📼 Retro ──
  EffectDef(key: 'vhs',         label: 'VHS',          icon: Icons.videocam_off,        accentColor: Color(0xFF795548), category: '📼 Retro'),
  EffectDef(key: 'bwfilm',      label: 'B&W Film',     icon: Icons.movie_filter,        accentColor: Color(0xFF607D8B), category: '📼 Retro'),
  EffectDef(key: 'oldmovie',    label: 'Old Movie',    icon: Icons.local_movies,        accentColor: Color(0xFFFF8F00), category: '📼 Retro'),
  EffectDef(key: 'film_grain',  label: 'Film Grain',   icon: Icons.grain,               accentColor: Color(0xFFBCAAA4), category: '📼 Retro'),
  EffectDef(key: 'crt',         label: 'CRT Monitor',  icon: Icons.monitor,             accentColor: Color(0xFF4CAF50), category: '📼 Retro'),
  EffectDef(key: 'vignette',    label: 'Vignette',     icon: Icons.vignette,            accentColor: Color(0xFF37474F), category: '📼 Retro'),
  EffectDef(key: 'retro_wave',  label: 'Retrowave',    icon: Icons.waves,               accentColor: Color(0xFFFF0080), category: '📼 Retro'),
  EffectDef(key: 'duotone',     label: 'Duotone',      icon: Icons.tonality,            accentColor: Color(0xFF7B1FA2), category: '📼 Retro'),
  EffectDef(key: 'hologram',    label: 'Hologram',     icon: Icons.view_in_ar,          accentColor: Color(0xFF00E5FF), category: '📼 Retro'),
  EffectDef(key: 'noise_static',label: 'TV Static',    icon: Icons.sensors_off,         accentColor: Color(0xFF9E9E9E), category: '📼 Retro'),

  // ── 🌿 Nature ──
  EffectDef(key: 'rain',        label: 'Rain',         icon: Icons.water_drop,          accentColor: Color(0xFF1976D2), category: '🌿 Nature'),
  EffectDef(key: 'snow',        label: 'Snow',         icon: Icons.ac_unit,             accentColor: Color(0xFF90CAF9), category: '🌿 Nature'),
  EffectDef(key: 'lensflare',   label: 'Lens Flare',   icon: Icons.wb_sunny,            accentColor: Color(0xFFFFC107), category: '🌿 Nature'),
  EffectDef(key: 'fireflies',   label: 'Fireflies',    icon: Icons.nightlight,          accentColor: Color(0xFFFFEB3B), category: '🌿 Nature'),
  EffectDef(key: 'petals',      label: 'Petals',       icon: Icons.local_florist,       accentColor: Color(0xFFFF80AB), category: '🌿 Nature'),
  EffectDef(key: 'aurora',      label: 'Aurora',       icon: Icons.auto_awesome,        accentColor: Color(0xFF00E676), category: '🌿 Nature'),
  EffectDef(key: 'fog',         label: 'Fog',          icon: Icons.blur_on,             accentColor: Color(0xFFB0BEC5), category: '🌿 Nature'),
  EffectDef(key: 'lightning',   label: 'Lightning',    icon: Icons.electric_bolt,       accentColor: Color(0xFFFFEE58), category: '🌿 Nature'),
  EffectDef(key: 'underwater',  label: 'Underwater',   icon: Icons.pool,                accentColor: Color(0xFF006064), category: '🌿 Nature'),
  EffectDef(key: 'stars',       label: 'Starfield',    icon: Icons.star,                accentColor: Color(0xFFFFF9C4), category: '🌿 Nature'),

  // ── 🎉 Party ──
  EffectDef(key: 'neon',        label: 'Neon',         icon: Icons.local_bar,           accentColor: Color(0xFFE040FB), category: '🎉 Party'),
  EffectDef(key: 'sparkle',     label: 'Sparkles',     icon: Icons.auto_fix_high,       accentColor: Color(0xFFFFEB3B), category: '🎉 Party'),
  EffectDef(key: 'confetti',    label: 'Confetti',     icon: Icons.celebration,         accentColor: Color(0xFFFF5722), category: '🎉 Party'),
  EffectDef(key: 'disco',       label: 'Disco',        icon: Icons.music_note,          accentColor: Color(0xFFFF4081), category: '🎉 Party'),
  EffectDef(key: 'laser',       label: 'Laser Grid',   icon: Icons.grid_4x4,            accentColor: Color(0xFF76FF03), category: '🎉 Party'),
  EffectDef(key: 'hearts',      label: 'Hearts',       icon: Icons.favorite,            accentColor: Color(0xFFFF1744), category: '🎉 Party'),
  EffectDef(key: 'bubbles',     label: 'Bubbles',      icon: Icons.bubble_chart,        accentColor: Color(0xFF40C4FF), category: '🎉 Party'),
  EffectDef(key: 'explosion',   label: 'Burst',        icon: Icons.whatshot,            accentColor: Color(0xFFFF6D00), category: '🎉 Party'),
  EffectDef(key: 'rainbow',     label: 'Rainbow',      icon: Icons.palette,             accentColor: Color(0xFFFFD600), category: '🎉 Party'),
  EffectDef(key: 'matrix',      label: 'Matrix',       icon: Icons.code,                accentColor: Color(0xFF00E676), category: '🎉 Party'),

  // ── 🔮 Aesthetic ──
  EffectDef(key: 'dreamy',      label: 'Dreamy',       icon: Icons.cloud,               accentColor: Color(0xFFCE93D8), category: '🔮 Aesthetic'),
  EffectDef(key: 'lofi',        label: 'Lo-Fi',        icon: Icons.headphones,          accentColor: Color(0xFFA5D6A7), category: '🔮 Aesthetic'),
  EffectDef(key: 'prism',       label: 'Prism',        icon: Icons.filter_drama,        accentColor: Color(0xFF80DEEA), category: '🔮 Aesthetic'),
  EffectDef(key: 'glimmer',     label: 'Glimmer',      icon: Icons.brightness_high,     accentColor: Color(0xFFFFD54F), category: '🔮 Aesthetic'),
  EffectDef(key: 'portal',      label: 'Portal',       icon: Icons.motion_photos_on,    accentColor: Color(0xFF1DE9B6), category: '🔮 Aesthetic'),
  EffectDef(key: 'smoke',       label: 'Smoke',        icon: Icons.cloud_queue,         accentColor: Color(0xFF90A4AE), category: '🔮 Aesthetic'),
  EffectDef(key: 'ink_drop',    label: 'Ink Drop',     icon: Icons.water,               accentColor: Color(0xFF311B92), category: '🔮 Aesthetic'),
  EffectDef(key: 'crystal',     label: 'Crystal',      icon: Icons.diamond,             accentColor: Color(0xFF80CBC4), category: '🔮 Aesthetic'),
  EffectDef(key: 'fire',        label: 'Fire',         icon: Icons.local_fire_department,accentColor:Color(0xFFFF3D00), category: '🔮 Aesthetic'),
  EffectDef(key: 'tv_lines',    label: 'TV Lines',     icon: Icons.view_stream,         accentColor: Color(0xFF546E7A), category: '🔮 Aesthetic'),


  // ── ⚡ Visual ── list එකේ අගට
  EffectDef(key: 'heat_wave',    label: 'Heat Wave',    icon: Icons.thermostat,          accentColor: Color(0xFFFF6E40), category: '⚡ Visual'),
  EffectDef(key: 'pixel_sort',   label: 'Pixel Sort',   icon: Icons.sort,                accentColor: Color(0xFF69F0AE), category: '⚡ Visual'),

// ── 📼 Retro ── list එකේ අගට
  EffectDef(key: 'light_leak',   label: 'Light Leak',   icon: Icons.light_mode,          accentColor: Color(0xFFFFD180), category: '📼 Retro'),
  EffectDef(key: 'vaporwave',    label: 'Vaporwave',    icon: Icons.gradient,            accentColor: Color(0xFFEA80FC), category: '📼 Retro'),

// ── 🌿 Nature ── list එකේ අගට
  EffectDef(key: 'bokeh',        label: 'Bokeh',        icon: Icons.blur_circular,       accentColor: Color(0xFFFFECB3), category: '🌿 Nature'),
  EffectDef(key: 'warp_speed',   label: 'Warp Speed',   icon: Icons.rocket_launch,       accentColor: Color(0xFFB3E5FC), category: '🌿 Nature'),

// ── 🎉 Party ── list එකේ අගට
  EffectDef(key: 'glitter',      label: 'Glitter',      icon: Icons.auto_fix_normal,     accentColor: Color(0xFFFFD54F), category: '🎉 Party'),

// ── 🔮 Aesthetic ── list එකේ අගට
  EffectDef(key: 'cinematic',    label: 'Cinematic',    icon: Icons.movie,               accentColor: Color(0xFF90A4AE), category: '🔮 Aesthetic'),
  EffectDef(key: 'comic',        label: 'Comic Pop',    icon: Icons.format_bold,         accentColor: Color(0xFFFFFF00), category: '🔮 Aesthetic'),
  EffectDef(key: 'neon_trails',  label: 'Neon Trails',  icon: Icons.timeline,            accentColor: Color(0xFF18FFFF), category: '🔮 Aesthetic'),
];



// ── Top-level buildEffectOverlay ──────────────────────────────────────────────

Widget buildEffectOverlay(String effectKey, double intensity) {
  switch (effectKey) {
    case 'glitch':       return EffectGlitchOverlay(intensity: intensity);
    case 'vhs':          return EffectVhsOverlay(intensity: intensity);
    case 'rain':         return EffectRainOverlay(intensity: intensity);
    case 'snow':         return EffectSnowOverlay(intensity: intensity);
    case 'sparkle':      return EffectSparkleOverlay(intensity: intensity);
    case 'neon':         return EffectNeonOverlay(intensity: intensity);
    case 'rgb':          return EffectRgbOverlay(intensity: intensity);
    case 'mirror':       return EffectMirrorOverlay(intensity: intensity);
    case 'zoom_pulse':   return EffectZoomPulseOverlay(intensity: intensity);
    case 'color_shift':  return EffectColorShiftOverlay(intensity: intensity);
    case 'invert':       return EffectInvertOverlay(intensity: intensity);
    case 'scanline':     return EffectScanlineOverlay(intensity: intensity);
    case 'edge_glow':    return EffectEdgeGlowOverlay(intensity: intensity);
    case 'kaleidoscope': return EffectKaleidoscopeOverlay(intensity: intensity);
    case 'film_grain':   return EffectFilmGrainOverlay(intensity: intensity);
    case 'crt':          return EffectCrtOverlay(intensity: intensity);
    case 'vignette':     return EffectVignetteOverlay(intensity: intensity);
    case 'retro_wave':   return EffectRetroWaveOverlay(intensity: intensity);
    case 'duotone':      return EffectDuotoneOverlay(intensity: intensity);
    case 'hologram':     return EffectHologramOverlay(intensity: intensity);
    case 'noise_static': return EffectNoiseStaticOverlay(intensity: intensity);
    case 'fireflies':    return EffectFirefliesOverlay(intensity: intensity);
    case 'petals':       return EffectPetalsOverlay(intensity: intensity);
    case 'aurora':       return EffectAuroraOverlay(intensity: intensity);
    case 'fog':          return EffectFogOverlay(intensity: intensity);
    case 'lightning':    return EffectLightningOverlay(intensity: intensity);
    case 'underwater':   return EffectUnderwaterOverlay(intensity: intensity);
    case 'stars':        return EffectStarsOverlay(intensity: intensity);
    case 'confetti':     return EffectConfettiOverlay(intensity: intensity);
    case 'disco':        return EffectDiscoOverlay(intensity: intensity);
    case 'laser':        return EffectLaserOverlay(intensity: intensity);
    case 'hearts':       return EffectHeartsOverlay(intensity: intensity);
    case 'bubbles':      return EffectBubblesOverlay(intensity: intensity);
    case 'explosion':    return EffectExplosionOverlay(intensity: intensity);
    case 'rainbow':      return EffectRainbowOverlay(intensity: intensity);
    case 'matrix':       return EffectMatrixOverlay(intensity: intensity);
    case 'dreamy':       return EffectDreamyOverlay(intensity: intensity);
    case 'lofi':         return EffectLofiOverlay(intensity: intensity);
    case 'prism':        return EffectPrismOverlay(intensity: intensity);
    case 'glimmer':      return EffectGlimmerOverlay(intensity: intensity);
    case 'portal':       return EffectPortalOverlay(intensity: intensity);
    case 'smoke':        return EffectSmokeOverlay(intensity: intensity);
    case 'ink_drop':     return EffectInkDropOverlay(intensity: intensity);
    case 'crystal':      return EffectCrystalOverlay(intensity: intensity);
    case 'fire':         return EffectFireOverlay(intensity: intensity);
    case 'tv_lines':     return EffectTvLinesOverlay(intensity: intensity);
    case 'lensflare':    return EffectLensFlareOverlay(intensity: intensity);
    case 'heat_wave':    return EffectHeatWaveOverlay(intensity: intensity);
    case 'pixel_sort':   return EffectPixelSortOverlay(intensity: intensity);
    case 'light_leak':   return EffectLightLeakOverlay(intensity: intensity);
    case 'vaporwave':    return EffectVaporwaveOverlay(intensity: intensity);
    case 'bokeh':        return EffectBokehOverlay(intensity: intensity);
    case 'warp_speed':   return EffectWarpSpeedOverlay(intensity: intensity);
    case 'glitter':      return EffectGlitterOverlay(intensity: intensity);
    case 'cinematic':    return EffectCinematicOverlay(intensity: intensity);
    case 'comic':        return EffectComicOverlay(intensity: intensity);
    case 'neon_trails':  return EffectNeonTrailsOverlay(intensity: intensity);
    default:             return const SizedBox.shrink();
  }
}

class _HeatWavePrev extends StatelessWidget {
  final double t; final Color color;
  const _HeatWavePrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Transform.translate(
    offset: Offset(sin(t * pi * 3) * 3, 0),
    child: Icon(Icons.thermostat, color: const Color(0xFFFF6E40).withOpacity(0.5 + t * 0.5), size: 26),
  );
}

class _PixelSortPrev extends StatelessWidget {
  final double t; final Color color;
  const _PixelSortPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _PSPrev(t: t));
}
class _PSPrev extends CustomPainter {
  final double t;
  _PSPrev({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random((t * 100).toInt());
    for (int i = 0; i < 5; i++) {
      final y = i * size.height / 5;
      final w = (0.3 + rng.nextDouble() * 0.6) * size.width;
      canvas.drawRect(Rect.fromLTWH(0, y + 1, w, size.height / 5 - 2),
          Paint()..color = HSVColor.fromAHSV(0.7, rng.nextDouble() * 360, 1.0, 1.0).toColor());
    }
  }
  @override bool shouldRepaint(_PSPrev old) => old.t != t;
}

class _LightLeakPrev extends StatelessWidget {
  final double t; final Color color;
  const _LightLeakPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment.topLeft,
        colors: [const Color(0xFFFFD180).withOpacity(0.5 + t * 0.4), Colors.transparent],
        radius: 1.2,
      ),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Icon(Icons.light_mode, color: Colors.white.withOpacity(0.7 + t * 0.3), size: 22),
  );
}

class _VaporwavePrev extends StatelessWidget {
  final double t; final Color color;
  const _VaporwavePrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [const Color(0xFFEA80FC).withOpacity(0.7), const Color(0xFF40C4FF).withOpacity(0.7)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Icon(Icons.gradient, color: Colors.white, size: 22),
  );
}

class _BokehPrev extends StatelessWidget {
  final double t; final Color color;
  const _BokehPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _BokP(t: t));
}
class _BokP extends CustomPainter {
  final double t;
  _BokP({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(44);
    final colors = [const Color(0xFFFFECB3), const Color(0xFFB3E5FC), const Color(0xFFE1BEE7)];
    for (int i = 0; i < 5; i++) {
      final alpha = sin((t * 2 * pi + i * 0.5) % (2 * pi)).abs() * 0.7;
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        6 + rng.nextDouble() * 8,
        Paint()
          ..color = colors[i % 3].withOpacity(alpha * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }
  @override bool shouldRepaint(_BokP old) => old.t != t;
}

class _WarpSpeedPrev extends StatelessWidget {
  final double t; final Color color;
  const _WarpSpeedPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _WPrev(t: t));
}
class _WPrev extends CustomPainter {
  final double t;
  _WPrev({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    final rng = Random(55);
    for (int i = 0; i < 12; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final r = t * 22;
      canvas.drawLine(
        Offset(cx + cos(angle) * r * 0.3, cy + sin(angle) * r * 0.3),
        Offset(cx + cos(angle) * r, cy + sin(angle) * r),
        Paint()..color = Colors.white.withOpacity((1 - t) * 0.8)..strokeWidth = 1,
      );
    }
  }
  @override bool shouldRepaint(_WPrev old) => old.t != t;
}

class _GlitterPrev extends StatelessWidget {
  final double t; final Color color;
  const _GlitterPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _GlitP(t: t));
}
class _GlitP extends CustomPainter {
  final double t;
  _GlitP({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random((t * 5000).toInt());
    for (int i = 0; i < 10; i++) {
      if (rng.nextDouble() > 0.5) {
        final cx = rng.nextDouble() * size.width;
        final cy = rng.nextDouble() * size.height;
        final r = 2 + rng.nextDouble() * 3;
        final p = Paint()..color = const Color(0xFFFFD54F).withOpacity(rng.nextDouble())..strokeWidth = 1;
        canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), p);
        canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), p);
      }
    }
  }
  @override bool shouldRepaint(_GlitP old) => old.t != t;
}

class _CinematicPrev extends StatelessWidget {
  final double t; final Color color;
  const _CinematicPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Stack(children: [
    Icon(Icons.movie, color: color, size: 26),
    Positioned(top: 0, left: 0, right: 0, child: Container(height: 7, color: Colors.black)),
    Positioned(bottom: 0, left: 0, right: 0, child: Container(height: 7, color: Colors.black)),
  ]);
}

class _ComicPrev extends StatelessWidget {
  final double t; final Color color;
  const _ComicPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _ComP(t: t));
}
class _ComP extends CustomPainter {
  final double t;
  _ComP({required this.t});
  @override void paint(Canvas canvas, Size size) {
    const spacing = 7.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 2, Paint()..color = Colors.black.withOpacity(0.15));
      }
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFFFFF00).withOpacity(sin(t * 2 * pi).abs() * 0.15),
    );
  }
  @override bool shouldRepaint(_ComP old) => old.t != t;
}

class _NeonTrailsPrev extends StatelessWidget {
  final double t; final Color color;
  const _NeonTrailsPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _NTPrev(t: t));
}
class _NTPrev extends CustomPainter {
  final double t;
  _NTPrev({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final colors = [const Color(0xFF18FFFF), const Color(0xFFE040FB), const Color(0xFF76FF03)];
    for (int i = 0; i < 3; i++) {
      final x = size.width * (0.25 + i * 0.25);
      final topY = size.height * (1 - t * (0.5 + i * 0.15));
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + sin(t * pi + i) * 5, topY),
        Paint()
          ..color = colors[i].withOpacity(0.7)
          ..strokeWidth = 2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }
  @override bool shouldRepaint(_NTPrev old) => old.t != t;
}

// ════════════════════════════════════════════════════════════════════════════
// EFFECT OVERLAYS
// ════════════════════════════════════════════════════════════════════════════

// ── Glitch ────────────────────────────────────────────────────────────────────
class EffectGlitchOverlay extends StatefulWidget {
  final double intensity;
  const EffectGlitchOverlay({super.key, required this.intensity});
  @override State<EffectGlitchOverlay> createState() => _EffectGlitchOverlayState();
}
class _EffectGlitchOverlayState extends State<EffectGlitchOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150))..repeat(reverse: true); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) {
      final offset = (_ctrl.value - 0.5) * 20 * widget.intensity;
      return Stack(fit: StackFit.expand, children: [
        Transform.translate(offset: Offset(offset, 0), child: ColorFiltered(colorFilter: ColorFilter.mode(Colors.red.withOpacity(0.25 * widget.intensity), BlendMode.srcOver), child: Container(color: Colors.transparent))),
        Transform.translate(offset: Offset(-offset, 0), child: ColorFiltered(colorFilter: ColorFilter.mode(Colors.blue.withOpacity(0.25 * widget.intensity), BlendMode.srcOver), child: Container(color: Colors.transparent))),
        CustomPaint(painter: _GlitchBarPainter(t: _ctrl.value, intensity: widget.intensity)),
      ]);
    },
  );
}
class _GlitchBarPainter extends CustomPainter {
  final double t; final double intensity;
  _GlitchBarPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random((t * 1000).toInt());
    for (int i = 0; i < (intensity * 6).toInt(); i++) {
      final y = rng.nextDouble() * size.height;
      canvas.drawRect(Rect.fromLTWH((rng.nextDouble() - 0.5) * 30 * intensity, y, size.width, rng.nextDouble() * 6 + 1), Paint()..color = Colors.white.withOpacity(0.08 * intensity));
    }
  }
  @override bool shouldRepaint(_GlitchBarPainter old) => old.t != t;
}

// ── VHS ───────────────────────────────────────────────────────────────────────
class EffectVhsOverlay extends StatefulWidget {
  final double intensity;
  const EffectVhsOverlay({super.key, required this.intensity});
  @override State<EffectVhsOverlay> createState() => _EffectVhsOverlayState();
}
class _EffectVhsOverlayState extends State<EffectVhsOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _VhsOverlayPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _VhsOverlayPainter extends CustomPainter {
  final double t; final double intensity;
  _VhsOverlayPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final lp = Paint()..color = Colors.black.withOpacity(0.08 * intensity)..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) canvas.drawLine(Offset(0, y), Offset(size.width, y), lp);
    final barY = (t * size.height * 1.3) % (size.height + 40) - 20;
    canvas.drawRect(Rect.fromLTWH(0, barY, size.width, 18), Paint()..color = Colors.white.withOpacity(0.06 * intensity));
    final rng = Random((t * 30).toInt());
    for (int i = 0; i < (intensity * 40).toInt(); i++) canvas.drawCircle(Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height), 0.8, Paint()..color = Colors.white.withOpacity(0.4 * intensity));
  }
  @override bool shouldRepaint(_VhsOverlayPainter old) => old.t != t;
}

// ── Rain ──────────────────────────────────────────────────────────────────────
class EffectRainOverlay extends StatefulWidget {
  final double intensity;
  const EffectRainOverlay({super.key, required this.intensity});
  @override State<EffectRainOverlay> createState() => _EffectRainOverlayState();
}
class _EffectRainOverlayState extends State<EffectRainOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _RainOverlayPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _RainOverlayPainter extends CustomPainter {
  final double t; final double intensity;
  _RainOverlayPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.lightBlueAccent.withOpacity(0.55 * intensity)..strokeWidth = 1.2;
    final rng = Random(42);
    for (int i = 0; i < (intensity * 60).toInt(); i++) {
      final x = rng.nextDouble() * size.width;
      final y = (rng.nextDouble() * size.height + t * size.height * 1.8) % size.height;
      canvas.drawLine(Offset(x, y), Offset(x - 1.5, y + 14), paint);
    }
  }
  @override bool shouldRepaint(_RainOverlayPainter old) => old.t != t;
}

// ── Snow ──────────────────────────────────────────────────────────────────────
class EffectSnowOverlay extends StatefulWidget {
  final double intensity;
  const EffectSnowOverlay({super.key, required this.intensity});
  @override State<EffectSnowOverlay> createState() => _EffectSnowOverlayState();
}
class _EffectSnowOverlayState extends State<EffectSnowOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _SnowOverlayPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _SnowOverlayPainter extends CustomPainter {
  final double t; final double intensity;
  _SnowOverlayPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.85 * intensity);
    final rng = Random(99);
    for (int i = 0; i < (intensity * 50).toInt(); i++) {
      final x = rng.nextDouble() * size.width + sin(t * 2 * pi + i * 0.5) * 8;
      final y = (rng.nextDouble() * size.height + t * size.height) % size.height;
      canvas.drawCircle(Offset(x, y), 1.5 + rng.nextDouble() * 2.5, paint);
    }
  }
  @override bool shouldRepaint(_SnowOverlayPainter old) => old.t != t;
}

// ── Sparkle ───────────────────────────────────────────────────────────────────
class EffectSparkleOverlay extends StatefulWidget {
  final double intensity;
  const EffectSparkleOverlay({super.key, required this.intensity});
  @override State<EffectSparkleOverlay> createState() => _EffectSparkleOverlayState();
}
class _EffectSparkleOverlayState extends State<EffectSparkleOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _SparkleOverlayPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _SparkleOverlayPainter extends CustomPainter {
  final double t; final double intensity;
  _SparkleOverlayPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(55);
    for (int i = 0; i < (intensity * 20).toInt(); i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final alpha = sin(((t + i * 0.15) % 1.0) * pi).clamp(0.0, 1.0);
      final paint = Paint()..color = Colors.yellow.withOpacity(alpha * intensity)..strokeWidth = 1.5..strokeCap = StrokeCap.round;
      final r = 6.0 + rng.nextDouble() * 6;
      for (int j = 0; j < 4; j++) {
        final angle = j * pi / 4;
        canvas.drawLine(Offset(cx - cos(angle) * r, cy - sin(angle) * r), Offset(cx + cos(angle) * r, cy + sin(angle) * r), paint);
      }
    }
  }
  @override bool shouldRepaint(_SparkleOverlayPainter old) => old.t != t;
}

// ── Neon ──────────────────────────────────────────────────────────────────────
class EffectNeonOverlay extends StatefulWidget {
  final double intensity;
  const EffectNeonOverlay({super.key, required this.intensity});
  @override State<EffectNeonOverlay> createState() => _EffectNeonOverlayState();
}
class _EffectNeonOverlayState extends State<EffectNeonOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.purpleAccent.withOpacity((0.3 + _ctrl.value * 0.4) * widget.intensity), width: 3 + _ctrl.value * 4)),
      foregroundDecoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.pinkAccent.withOpacity(0.08 * widget.intensity * _ctrl.value), Colors.transparent, Colors.purpleAccent.withOpacity(0.08 * widget.intensity * _ctrl.value)])),
    ),
  );
}

// ── RGB Split ─────────────────────────────────────────────────────────────────
class EffectRgbOverlay extends StatefulWidget {
  final double intensity;
  const EffectRgbOverlay({super.key, required this.intensity});
  @override State<EffectRgbOverlay> createState() => _EffectRgbOverlayState();
}
class _EffectRgbOverlayState extends State<EffectRgbOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..repeat(reverse: true); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) {
      final shift = _ctrl.value * 12 * widget.intensity;
      return Stack(fit: StackFit.expand, children: [
        Transform.translate(offset: Offset(-shift, 0), child: ColorFiltered(colorFilter: ColorFilter.mode(Colors.red.withOpacity(0.18 * widget.intensity), BlendMode.srcOver), child: Container(color: Colors.transparent))),
        Transform.translate(offset: Offset(shift, 0), child: ColorFiltered(colorFilter: ColorFilter.mode(Colors.blue.withOpacity(0.18 * widget.intensity), BlendMode.srcOver), child: Container(color: Colors.transparent))),
      ]);
    },
  );
}

// ── Mirror ────────────────────────────────────────────────────────────────────
class EffectMirrorOverlay extends StatelessWidget {
  final double intensity;
  const EffectMirrorOverlay({super.key, required this.intensity});
  @override Widget build(BuildContext context) => LayoutBuilder(builder: (_, constraints) => Stack(fit: StackFit.expand, children: [Center(child: Container(width: 1.5, height: constraints.maxHeight, color: Colors.white.withOpacity(0.3 * intensity)))]));
}

// ── Zoom Pulse ────────────────────────────────────────────────────────────────
class EffectZoomPulseOverlay extends StatefulWidget {
  final double intensity;
  const EffectZoomPulseOverlay({super.key, required this.intensity});
  @override State<EffectZoomPulseOverlay> createState() => _EffectZoomPulseOverlayState();
}
class _EffectZoomPulseOverlayState extends State<EffectZoomPulseOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, child) {
      final scale = 1.0 + _ctrl.value * 0.06 * widget.intensity;
      return Transform.scale(scale: scale, child: Container(decoration: BoxDecoration(gradient: RadialGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.15 * widget.intensity * _ctrl.value)]))));
    },
  );
}

// ── Color Shift ───────────────────────────────────────────────────────────────
class EffectColorShiftOverlay extends StatefulWidget {
  final double intensity;
  const EffectColorShiftOverlay({super.key, required this.intensity});
  @override State<EffectColorShiftOverlay> createState() => _EffectColorShiftOverlayState();
}
class _EffectColorShiftOverlayState extends State<EffectColorShiftOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) {
      final hue = _ctrl.value * 360;
      return Container(color: HSVColor.fromAHSV(0.12 * widget.intensity, hue, 1.0, 1.0).toColor());
    },
  );
}

// ── Invert ────────────────────────────────────────────────────────────────────
class EffectInvertOverlay extends StatefulWidget {
  final double intensity;
  const EffectInvertOverlay({super.key, required this.intensity});
  @override State<EffectInvertOverlay> createState() => _EffectInvertOverlayState();
}
class _EffectInvertOverlayState extends State<EffectInvertOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => ColorFiltered(
      colorFilter: ColorFilter.matrix([
        -widget.intensity * _ctrl.value, 0, 0, 0, 255 * widget.intensity * _ctrl.value,
        0, -widget.intensity * _ctrl.value, 0, 0, 255 * widget.intensity * _ctrl.value,
        0, 0, -widget.intensity * _ctrl.value, 0, 255 * widget.intensity * _ctrl.value,
        0, 0, 0, 1, 0,
      ]),
      child: Container(color: Colors.white.withOpacity(0.0)),
    ),
  );
}

// ── Scanline ──────────────────────────────────────────────────────────────────
class EffectScanlineOverlay extends StatelessWidget {
  final double intensity;
  const EffectScanlineOverlay({super.key, required this.intensity});
  @override Widget build(BuildContext context) => CustomPaint(painter: _ScanlinePainter(intensity: intensity));
}
class _ScanlinePainter extends CustomPainter {
  final double intensity;
  _ScanlinePainter({required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.15 * intensity)..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 2) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  @override bool shouldRepaint(_ScanlinePainter old) => false;
}

// ── Edge Glow ─────────────────────────────────────────────────────────────────
class EffectEdgeGlowOverlay extends StatefulWidget {
  final double intensity;
  const EffectEdgeGlowOverlay({super.key, required this.intensity});
  @override State<EffectEdgeGlowOverlay> createState() => _EffectEdgeGlowOverlayState();
}
class _EffectEdgeGlowOverlayState extends State<EffectEdgeGlowOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
          Colors.orange.withOpacity(0.3 * widget.intensity * _ctrl.value),
          Colors.transparent,
          Colors.deepOrange.withOpacity(0.3 * widget.intensity * (1 - _ctrl.value)),
        ]),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.5 * widget.intensity * _ctrl.value), width: 2 + _ctrl.value * 3),
      ),
    ),
  );
}

// ── Kaleidoscope ──────────────────────────────────────────────────────────────
class EffectKaleidoscopeOverlay extends StatefulWidget {
  final double intensity;
  const EffectKaleidoscopeOverlay({super.key, required this.intensity});
  @override State<EffectKaleidoscopeOverlay> createState() => _EffectKaleidoscopeOverlayState();
}
class _EffectKaleidoscopeOverlayState extends State<EffectKaleidoscopeOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _KaleidoscopePainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _KaleidoscopePainter extends CustomPainter {
  final double t; final double intensity;
  _KaleidoscopePainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3 + t * 2 * pi;
      final r = 80 + 40 * sin(t * 2 * pi + i);
      final colors = [Color(0xAAFF00FF), Color(0xAA00FFFF), Color(0xAAFFFF00)];
      final paint = Paint()..color = colors[i % 3].withOpacity(0.15 * intensity)..style = PaintingStyle.fill;
      final path = Path()..moveTo(cx, cy)..lineTo(cx + cos(angle) * r, cy + sin(angle) * r)..lineTo(cx + cos(angle + pi / 3) * r, cy + sin(angle + pi / 3) * r)..close();
      canvas.drawPath(path, paint);
    }
  }
  @override bool shouldRepaint(_KaleidoscopePainter old) => old.t != t;
}

// ── Film Grain ────────────────────────────────────────────────────────────────
class EffectFilmGrainOverlay extends StatefulWidget {
  final double intensity;
  const EffectFilmGrainOverlay({super.key, required this.intensity});
  @override State<EffectFilmGrainOverlay> createState() => _EffectFilmGrainOverlayState();
}
class _EffectFilmGrainOverlayState extends State<EffectFilmGrainOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 80))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _FilmGrainPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _FilmGrainPainter extends CustomPainter {
  final double t; final double intensity;
  _FilmGrainPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random((t * 10000).toInt());
    final paint = Paint();
    for (int i = 0; i < (intensity * 800).toInt(); i++) {
      final brightness = rng.nextDouble();
      paint.color = (brightness > 0.5 ? Colors.white : Colors.black).withOpacity(rng.nextDouble() * 0.25 * intensity);
      canvas.drawCircle(Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height), 0.6, paint);
    }
  }
  @override bool shouldRepaint(_FilmGrainPainter old) => old.t != t;
}

// ── CRT Monitor ───────────────────────────────────────────────────────────────
class EffectCrtOverlay extends StatefulWidget {
  final double intensity;
  const EffectCrtOverlay({super.key, required this.intensity});
  @override State<EffectCrtOverlay> createState() => _EffectCrtOverlayState();
}
class _EffectCrtOverlayState extends State<EffectCrtOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _CrtPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _CrtPainter extends CustomPainter {
  final double t; final double intensity;
  _CrtPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final lp = Paint()..color = Colors.black.withOpacity(0.2 * intensity)..strokeWidth = 1.5;
    for (double y = 0; y < size.height; y += 3) canvas.drawLine(Offset(0, y), Offset(size.width, y), lp);
    final scanY = (t * size.height * 0.7) % (size.height + 20) - 10;
    canvas.drawRect(Rect.fromLTWH(0, scanY, size.width, 4), Paint()..color = Colors.green.withOpacity(0.12 * intensity));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.transparent..style = PaintingStyle.stroke..strokeWidth = 0);
    final vigPaint = Paint()..shader = RadialGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.35 * intensity)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vigPaint);
  }
  @override bool shouldRepaint(_CrtPainter old) => old.t != t;
}

// ── Vignette ──────────────────────────────────────────────────────────────────
class EffectVignetteOverlay extends StatelessWidget {
  final double intensity;
  const EffectVignetteOverlay({super.key, required this.intensity});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) => CustomPaint(size: Size(c.maxWidth, c.maxHeight), painter: _VignettePainter(intensity: intensity)));
}
class _VignettePainter extends CustomPainter {
  final double intensity;
  _VignettePainter({required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..shader = RadialGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.8 * intensity)], stops: const [0.5, 1.0]).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }
  @override bool shouldRepaint(_VignettePainter old) => false;
}

// ── Retrowave ─────────────────────────────────────────────────────────────────
class EffectRetroWaveOverlay extends StatefulWidget {
  final double intensity;
  const EffectRetroWaveOverlay({super.key, required this.intensity});
  @override State<EffectRetroWaveOverlay> createState() => _EffectRetroWaveOverlayState();
}
class _EffectRetroWaveOverlayState extends State<EffectRetroWaveOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _RetroWavePainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _RetroWavePainter extends CustomPainter {
  final double t; final double intensity;
  _RetroWavePainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 5; i++) {
      final y = size.height * 0.5 + sin(t * 2 * pi + i * 0.5) * 30 * intensity + i * 20;
      final paint = Paint()..color = Color.lerp(const Color(0xFFFF0080), const Color(0xFF00FFFF), i / 5)!.withOpacity(0.4 * intensity)..strokeWidth = 2..style = PaintingStyle.stroke;
      final path = Path()..moveTo(0, y);
      for (double x = 0; x < size.width; x += 5) path.lineTo(x, y + sin(x / 30 + t * 2 * pi) * 10 * intensity);
      canvas.drawPath(path, paint);
    }
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0x00FF0080), const Color(0x33FF0080).withOpacity(0.2 * intensity)]).createShader(Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5)));
  }
  @override bool shouldRepaint(_RetroWavePainter old) => old.t != t;
}

// ── Duotone ───────────────────────────────────────────────────────────────────
class EffectDuotoneOverlay extends StatefulWidget {
  final double intensity;
  const EffectDuotoneOverlay({super.key, required this.intensity});
  @override State<EffectDuotoneOverlay> createState() => _EffectDuotoneOverlayState();
}
class _EffectDuotoneOverlayState extends State<EffectDuotoneOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
          const Color(0xFF7B1FA2).withOpacity(0.3 * widget.intensity * (0.5 + _ctrl.value * 0.5)),
          const Color(0xFFFF4081).withOpacity(0.3 * widget.intensity * (1 - _ctrl.value * 0.5)),
        ]),
      ),
    ),
  );
}

// ── Hologram ──────────────────────────────────────────────────────────────────
class EffectHologramOverlay extends StatefulWidget {
  final double intensity;
  const EffectHologramOverlay({super.key, required this.intensity});
  @override State<EffectHologramOverlay> createState() => _EffectHologramOverlayState();
}
class _EffectHologramOverlayState extends State<EffectHologramOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _HologramPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _HologramPainter extends CustomPainter {
  final double t; final double intensity;
  _HologramPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 8; i++) {
      final y = (i * size.height / 8 + t * size.height * 0.4) % size.height;
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2), Paint()..color = const Color(0xFF00E5FF).withOpacity(0.15 * intensity));
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF00E5FF).withOpacity(0.04 * intensity));
    final rng = Random((t * 20).toInt());
    for (int i = 0; i < (intensity * 5).toInt(); i++) {
      final flickerY = rng.nextDouble() * size.height;
      final flickerH = rng.nextDouble() * 10 + 2;
      canvas.drawRect(Rect.fromLTWH(0, flickerY, size.width * rng.nextDouble(), flickerH), Paint()..color = const Color(0xFF00E5FF).withOpacity(0.25 * intensity));
    }
  }
  @override bool shouldRepaint(_HologramPainter old) => old.t != t;
}

// ── TV Static / Noise ─────────────────────────────────────────────────────────
class EffectNoiseStaticOverlay extends StatefulWidget {
  final double intensity;
  const EffectNoiseStaticOverlay({super.key, required this.intensity});
  @override State<EffectNoiseStaticOverlay> createState() => _EffectNoiseStaticOverlayState();
}
class _EffectNoiseStaticOverlayState extends State<EffectNoiseStaticOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 50))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _NoiseStaticPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _NoiseStaticPainter extends CustomPainter {
  final double t; final double intensity;
  _NoiseStaticPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random((t * 100000).toInt());
    for (int i = 0; i < (intensity * 2000).toInt(); i++) {
      final v = rng.nextDouble();
      canvas.drawRect(Rect.fromLTWH(rng.nextDouble() * size.width, rng.nextDouble() * size.height, 2, 2), Paint()..color = (v > 0.5 ? Colors.white : Colors.black).withOpacity(v * 0.4 * intensity));
    }
  }
  @override bool shouldRepaint(_NoiseStaticPainter old) => old.t != t;
}

// ── Fireflies ─────────────────────────────────────────────────────────────────
class EffectFirefliesOverlay extends StatefulWidget {
  final double intensity;
  const EffectFirefliesOverlay({super.key, required this.intensity});
  @override State<EffectFirefliesOverlay> createState() => _EffectFirefliesOverlayState();
}
class _EffectFirefliesOverlayState extends State<EffectFirefliesOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _FirefliesPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _FirefliesPainter extends CustomPainter {
  final double t; final double intensity;
  _FirefliesPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(77);
    for (int i = 0; i < (intensity * 25).toInt(); i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final x = baseX + sin(t * 2 * pi * rng.nextDouble() + i) * 20;
      final y = baseY + cos(t * 2 * pi * rng.nextDouble() + i) * 20;
      final alpha = sin((t * 2 * pi + i * 0.8) % (2 * pi)).abs().clamp(0.0, 1.0);
      final p = Paint()..color = const Color(0xFFFFEB3B).withOpacity(alpha * intensity * 0.9)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(x, y), 3, p);
    }
  }
  @override bool shouldRepaint(_FirefliesPainter old) => old.t != t;
}

// ── Petals ────────────────────────────────────────────────────────────────────
class EffectPetalsOverlay extends StatefulWidget {
  final double intensity;
  const EffectPetalsOverlay({super.key, required this.intensity});
  @override State<EffectPetalsOverlay> createState() => _EffectPetalsOverlayState();
}
class _EffectPetalsOverlayState extends State<EffectPetalsOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _PetalsPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _PetalsPainter extends CustomPainter {
  final double t; final double intensity;
  _PetalsPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(33);
    final colors = [const Color(0xFFFFB3BA), const Color(0xFFFFD1DC), const Color(0xFFFFC0CB), const Color(0xFFFF69B4)];
    for (int i = 0; i < (intensity * 20).toInt(); i++) {
      final baseX = rng.nextDouble() * size.width;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final x = baseX + sin(t * 2 * pi * speed + i) * 25;
      final y = (rng.nextDouble() * size.height + t * size.height * speed) % size.height;
      final angle = t * 2 * pi * speed + i;
      final paint = Paint()..color = colors[i % colors.length].withOpacity(0.7 * intensity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      final path = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: 8, height: 14));
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }
  @override bool shouldRepaint(_PetalsPainter old) => old.t != t;
}

// ── Aurora ────────────────────────────────────────────────────────────────────
class EffectAuroraOverlay extends StatefulWidget {
  final double intensity;
  const EffectAuroraOverlay({super.key, required this.intensity});
  @override State<EffectAuroraOverlay> createState() => _EffectAuroraOverlayState();
}
class _EffectAuroraOverlayState extends State<EffectAuroraOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF00E676).withOpacity(0.25 * widget.intensity * (0.5 + sin(_ctrl.value * 2 * pi) * 0.5)),
            const Color(0xFF00BCD4).withOpacity(0.2 * widget.intensity * (0.5 + cos(_ctrl.value * 2 * pi) * 0.5)),
            const Color(0xFF7C4DFF).withOpacity(0.15 * widget.intensity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 0.6, 1.0],
        ),
      ),
    ),
  );
}

// ── Fog ───────────────────────────────────────────────────────────────────────
class EffectFogOverlay extends StatefulWidget {
  final double intensity;
  const EffectFogOverlay({super.key, required this.intensity});
  @override State<EffectFogOverlay> createState() => _EffectFogOverlayState();
}
class _EffectFogOverlayState extends State<EffectFogOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 5000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _FogPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _FogPainter extends CustomPainter {
  final double t; final double intensity;
  _FogPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) {
      final offsetX = sin(t * 2 * pi + i * 2) * 50;
      final offsetY = cos(t * pi + i) * 20;
      final paint = Paint()..color = Colors.white.withOpacity(0.08 * intensity)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
      canvas.drawOval(Rect.fromCenter(center: Offset(size.width * (0.3 + i * 0.2) + offsetX, size.height * 0.5 + offsetY), width: size.width * 0.6, height: size.height * 0.3), paint);
    }
  }
  @override bool shouldRepaint(_FogPainter old) => old.t != t;
}

// ── Lightning ─────────────────────────────────────────────────────────────────
class EffectLightningOverlay extends StatefulWidget {
  final double intensity;
  const EffectLightningOverlay({super.key, required this.intensity});
  @override State<EffectLightningOverlay> createState() => _EffectLightningOverlayState();
}
class _EffectLightningOverlayState extends State<EffectLightningOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _LightningPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _LightningPainter extends CustomPainter {
  final double t; final double intensity;
  _LightningPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    if ((t * 5).floor() % 4 != 0) return;
    final rng = Random((t * 1000).toInt());
    final paint = Paint()..color = Colors.yellow.withOpacity(0.8 * intensity)..strokeWidth = 2..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    double x = rng.nextDouble() * size.width;
    double y = 0;
    while (y < size.height) {
      final nx = x + (rng.nextDouble() - 0.5) * 40;
      final ny = y + 20 + rng.nextDouble() * 20;
      canvas.drawLine(Offset(x, y), Offset(nx, ny), paint);
      x = nx; y = ny;
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white.withOpacity(0.05 * intensity));
  }
  @override bool shouldRepaint(_LightningPainter old) => old.t != t;
}

// ── Underwater ────────────────────────────────────────────────────────────────
class EffectUnderwaterOverlay extends StatefulWidget {
  final double intensity;
  const EffectUnderwaterOverlay({super.key, required this.intensity});
  @override State<EffectUnderwaterOverlay> createState() => _EffectUnderwaterOverlayState();
}
class _EffectUnderwaterOverlayState extends State<EffectUnderwaterOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Stack(fit: StackFit.expand, children: [
      Container(color: const Color(0xFF006064).withOpacity(0.2 * widget.intensity)),
      CustomPaint(painter: _UnderwaterPainter(t: _ctrl.value, intensity: widget.intensity)),
    ]),
  );
}
class _UnderwaterPainter extends CustomPainter {
  final double t; final double intensity;
  _UnderwaterPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 4; i++) {
      final paint = Paint()..color = Colors.cyan.withOpacity(0.1 * intensity)..strokeWidth = size.width;
      final y = (i * size.height / 4 + t * size.height * 0.2) % size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y + sin(t * 2 * pi + i) * 20), paint);
    }
    final rng = Random(11);
    for (int i = 0; i < (intensity * 15).toInt(); i++) {
      final bx = rng.nextDouble() * size.width;
      final by = (rng.nextDouble() * size.height - t * size.height * 0.3) % size.height;
      canvas.drawCircle(Offset(bx + sin(t * 2 * pi + i) * 5, by), 2 + rng.nextDouble() * 4, Paint()..color = Colors.white.withOpacity(0.25 * intensity)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
  }
  @override bool shouldRepaint(_UnderwaterPainter old) => old.t != t;
}

// ── Starfield ─────────────────────────────────────────────────────────────────
class EffectStarsOverlay extends StatefulWidget {
  final double intensity;
  const EffectStarsOverlay({super.key, required this.intensity});
  @override State<EffectStarsOverlay> createState() => _EffectStarsOverlayState();
}
class _EffectStarsOverlayState extends State<EffectStarsOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _StarsPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _StarsPainter extends CustomPainter {
  final double t; final double intensity;
  _StarsPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(21);
    for (int i = 0; i < (intensity * 60).toInt(); i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final twinkle = sin(t * 2 * pi + i * 0.7).abs();
      canvas.drawCircle(Offset(x, y), 1 + rng.nextDouble() * 1.5, Paint()..color = Colors.white.withOpacity(twinkle * intensity));
    }
  }
  @override bool shouldRepaint(_StarsPainter old) => old.t != t;
}

// ── Confetti ──────────────────────────────────────────────────────────────────
class EffectConfettiOverlay extends StatefulWidget {
  final double intensity;
  const EffectConfettiOverlay({super.key, required this.intensity});
  @override State<EffectConfettiOverlay> createState() => _EffectConfettiOverlayState();
}
class _EffectConfettiOverlayState extends State<EffectConfettiOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _ConfettiPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _ConfettiPainter extends CustomPainter {
  final double t; final double intensity;
  _ConfettiPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(88);
    final colors = [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.pink, Colors.orange, Colors.purple];
    for (int i = 0; i < (intensity * 40).toInt(); i++) {
      final x = rng.nextDouble() * size.width + sin(t * 2 * pi + i) * 10;
      final y = (rng.nextDouble() * size.height + t * size.height) % size.height;
      final angle = t * 2 * pi * rng.nextDouble() + i;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 6, height: 10), Paint()..color = colors[i % colors.length].withOpacity(0.8 * intensity));
      canvas.restore();
    }
  }
  @override bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

// ── Disco ─────────────────────────────────────────────────────────────────────
class EffectDiscoOverlay extends StatefulWidget {
  final double intensity;
  const EffectDiscoOverlay({super.key, required this.intensity});
  @override State<EffectDiscoOverlay> createState() => _EffectDiscoOverlayState();
}
class _EffectDiscoOverlayState extends State<EffectDiscoOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) {
      final hue = (_ctrl.value * 360) % 360;
      return Container(color: HSVColor.fromAHSV(0.15 * widget.intensity, hue, 1.0, 1.0).toColor());
    },
  );
}

// ── Laser Grid ────────────────────────────────────────────────────────────────
class EffectLaserOverlay extends StatefulWidget {
  final double intensity;
  const EffectLaserOverlay({super.key, required this.intensity});
  @override State<EffectLaserOverlay> createState() => _EffectLaserOverlayState();
}
class _EffectLaserOverlayState extends State<EffectLaserOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _LaserPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _LaserPainter extends CustomPainter {
  final double t; final double intensity;
  _LaserPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF76FF03).withOpacity(0.5 * intensity)..strokeWidth = 1..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
    final step = 30 + sin(t * 2 * pi) * 10;
    for (double x = 0; x < size.width; x += step) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += step) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  @override bool shouldRepaint(_LaserPainter old) => old.t != t;
}

// ── Hearts ────────────────────────────────────────────────────────────────────
class EffectHeartsOverlay extends StatefulWidget {
  final double intensity;
  const EffectHeartsOverlay({super.key, required this.intensity});
  @override State<EffectHeartsOverlay> createState() => _EffectHeartsOverlayState();
}
class _EffectHeartsOverlayState extends State<EffectHeartsOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _HeartsPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _HeartsPainter extends CustomPainter {
  final double t; final double intensity;
  _HeartsPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(66);
    for (int i = 0; i < (intensity * 15).toInt(); i++) {
      final x = rng.nextDouble() * size.width;
      final y = (rng.nextDouble() * size.height - t * size.height * 0.4 + i * 30) % size.height;
      final s = 6 + rng.nextDouble() * 8;
      final alpha = (1 - y / size.height).clamp(0.0, 1.0);
      final paint = Paint()..color = const Color(0xFFFF1744).withOpacity(alpha * intensity);
      final path = Path();
      path.moveTo(x, y + s * 0.3);
      path.cubicTo(x - s, y - s * 0.5, x - s * 1.5, y + s * 0.5, x, y + s);
      path.cubicTo(x + s * 1.5, y + s * 0.5, x + s, y - s * 0.5, x, y + s * 0.3);
      canvas.drawPath(path, paint);
    }
  }
  @override bool shouldRepaint(_HeartsPainter old) => old.t != t;
}

// ── Bubbles ───────────────────────────────────────────────────────────────────
class EffectBubblesOverlay extends StatefulWidget {
  final double intensity;
  const EffectBubblesOverlay({super.key, required this.intensity});
  @override State<EffectBubblesOverlay> createState() => _EffectBubblesOverlayState();
}
class _EffectBubblesOverlayState extends State<EffectBubblesOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _BubblesPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _BubblesPainter extends CustomPainter {
  final double t; final double intensity;
  _BubblesPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(55);
    for (int i = 0; i < (intensity * 20).toInt(); i++) {
      final bx = rng.nextDouble() * size.width + sin(t * 2 * pi + i) * 8;
      final by = (size.height - (rng.nextDouble() * size.height + t * size.height * 0.5 + i * 20) % size.height);
      final r = 4 + rng.nextDouble() * 12;
      canvas.drawCircle(Offset(bx, by), r, Paint()..color = const Color(0xFF40C4FF).withOpacity(0.3 * intensity)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }
  @override bool shouldRepaint(_BubblesPainter old) => old.t != t;
}

// ── Burst / Explosion ─────────────────────────────────────────────────────────
class EffectExplosionOverlay extends StatefulWidget {
  final double intensity;
  const EffectExplosionOverlay({super.key, required this.intensity});
  @override State<EffectExplosionOverlay> createState() => _EffectExplosionOverlayState();
}
class _EffectExplosionOverlayState extends State<EffectExplosionOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _ExplosionPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _ExplosionPainter extends CustomPainter {
  final double t; final double intensity;
  _ExplosionPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    final rng = Random(44);
    for (int i = 0; i < 12; i++) {
      final angle = i * pi / 6;
      final r = t * 150 * intensity;
      final x = cx + cos(angle) * r;
      final y = cy + sin(angle) * r;
      final colors = [Colors.orange, Colors.red, Colors.yellow];
      final paint = Paint()..color = colors[i % 3].withOpacity((1 - t) * intensity)..strokeWidth = 3..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawLine(Offset(cx, cy), Offset(x, y), paint);
    }
    if (t < 0.3) canvas.drawCircle(Offset(cx, cy), t * 80, Paint()..color = Colors.white.withOpacity((0.3 - t) * 3 * intensity));
  }
  @override bool shouldRepaint(_ExplosionPainter old) => old.t != t;
}

// ── Rainbow ───────────────────────────────────────────────────────────────────
class EffectRainbowOverlay extends StatefulWidget {
  final double intensity;
  const EffectRainbowOverlay({super.key, required this.intensity});
  @override State<EffectRainbowOverlay> createState() => _EffectRainbowOverlayState();
}
class _EffectRainbowOverlayState extends State<EffectRainbowOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: List.generate(7, (i) => HSVColor.fromAHSV(0.15 * widget.intensity, (i * 51.4 + _ctrl.value * 360) % 360, 1.0, 1.0).toColor()),
        ),
      ),
    ),
  );
}

// ── Matrix ────────────────────────────────────────────────────────────────────
class EffectMatrixOverlay extends StatefulWidget {
  final double intensity;
  const EffectMatrixOverlay({super.key, required this.intensity});
  @override State<EffectMatrixOverlay> createState() => _EffectMatrixOverlayState();
}
class _EffectMatrixOverlayState extends State<EffectMatrixOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _MatrixPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _MatrixPainter extends CustomPainter {
  final double t; final double intensity;
  _MatrixPainter({required this.t, required this.intensity});
  static final _chars = '01アイウエオカキクケコ01アイウエ01';
  @override void paint(Canvas canvas, Size size) {
    final rng = Random((DateTime.now().millisecondsSinceEpoch / 100).toInt());
    final colW = 14.0;
    for (double x = 0; x < size.width; x += colW) {
      final count = (intensity * 8).toInt();
      for (int i = 0; i < count; i++) {
        final y = rng.nextDouble() * size.height;
        final char = _chars[rng.nextInt(_chars.length)];
        final alpha = rng.nextDouble() * intensity;
        final tp = TextPainter(text: TextSpan(text: char, style: TextStyle(color: const Color(0xFF00E676).withOpacity(alpha), fontSize: 12, fontFamily: 'monospace')), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(x, y));
      }
    }
  }
  @override bool shouldRepaint(_MatrixPainter old) => true;
}

// ── Dreamy ────────────────────────────────────────────────────────────────────
class EffectDreamyOverlay extends StatefulWidget {
  final double intensity;
  const EffectDreamyOverlay({super.key, required this.intensity});
  @override State<EffectDreamyOverlay> createState() => _EffectDreamyOverlayState();
}
class _EffectDreamyOverlayState extends State<EffectDreamyOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat(reverse: true); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(colors: [
          const Color(0xFFCE93D8).withOpacity(0.2 * widget.intensity * _ctrl.value),
          const Color(0xFF80DEEA).withOpacity(0.15 * widget.intensity * (1 - _ctrl.value)),
          Colors.transparent,
        ], stops: const [0.0, 0.5, 1.0]),
      ),
    ),
  );
}

// ── Lo-Fi ─────────────────────────────────────────────────────────────────────
class EffectLofiOverlay extends StatelessWidget {
  final double intensity;
  const EffectLofiOverlay({super.key, required this.intensity});
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
    Container(decoration: BoxDecoration(gradient: RadialGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.4 * intensity)], stops: const [0.5, 1.0]))),
    ColorFiltered(colorFilter: ColorFilter.matrix([0.9, 0.1, 0, 0, 10, 0.1, 0.85, 0.05, 0, 10, 0, 0.1, 0.8, 0, 15, 0, 0, 0, intensity, 0]), child: Container(color: Colors.transparent)),
  ]);
}

// ── Prism ─────────────────────────────────────────────────────────────────────
class EffectPrismOverlay extends StatefulWidget {
  final double intensity;
  const EffectPrismOverlay({super.key, required this.intensity});
  @override State<EffectPrismOverlay> createState() => _EffectPrismOverlayState();
}
class _EffectPrismOverlayState extends State<EffectPrismOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _PrismPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _PrismPainter extends CustomPainter {
  final double t; final double intensity;
  _PrismPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 5; i++) {
      final angle = t * 2 * pi + i * pi / 5;
      final x1 = size.width / 2 + cos(angle) * size.width;
      final y1 = size.height / 2 + sin(angle) * size.height;
      final hue = (i * 72 + t * 360) % 360;
      canvas.drawLine(Offset(size.width / 2, size.height / 2), Offset(x1, y1),
          Paint()..color = HSVColor.fromAHSV(0.2 * intensity, hue, 1.0, 1.0).toColor()..strokeWidth = 2..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
  }
  @override bool shouldRepaint(_PrismPainter old) => old.t != t;
}

// ── Glimmer ───────────────────────────────────────────────────────────────────
class EffectGlimmerOverlay extends StatefulWidget {
  final double intensity;
  const EffectGlimmerOverlay({super.key, required this.intensity});
  @override State<EffectGlimmerOverlay> createState() => _EffectGlimmerOverlayState();
}
class _EffectGlimmerOverlayState extends State<EffectGlimmerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _GlimmerPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _GlimmerPainter extends CustomPainter {
  final double t; final double intensity;
  _GlimmerPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(12);
    for (int i = 0; i < (intensity * 15).toInt(); i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final phase = (t + i * 0.2) % 1.0;
      final alpha = sin(phase * pi).clamp(0.0, 1.0);
      final paint = Paint()..color = Colors.white.withOpacity(alpha * intensity)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(cx, cy), 8 + 4 * alpha, paint);
    }
  }
  @override bool shouldRepaint(_GlimmerPainter old) => old.t != t;
}

// ── Portal ────────────────────────────────────────────────────────────────────
class EffectPortalOverlay extends StatefulWidget {
  final double intensity;
  const EffectPortalOverlay({super.key, required this.intensity});
  @override State<EffectPortalOverlay> createState() => _EffectPortalOverlayState();
}
class _EffectPortalOverlayState extends State<EffectPortalOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _PortalPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _PortalPainter extends CustomPainter {
  final double t; final double intensity;
  _PortalPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    for (int i = 5; i >= 1; i--) {
      final r = (size.width * 0.1 * i) + sin(t * 2 * pi + i) * 10;
      final alpha = (1 - i / 6.0) * intensity;
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = const Color(0xFF1DE9B6).withOpacity(alpha * 0.25)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
    for (int i = 0; i < 8; i++) {
      final angle = t * 2 * pi + i * pi / 4;
      canvas.drawLine(Offset(cx, cy), Offset(cx + cos(angle) * 80, cy + sin(angle) * 80), Paint()..color = const Color(0xFF1DE9B6).withOpacity(0.15 * intensity));
    }
  }
  @override bool shouldRepaint(_PortalPainter old) => old.t != t;
}

// ── Smoke ─────────────────────────────────────────────────────────────────────
class EffectSmokeOverlay extends StatefulWidget {
  final double intensity;
  const EffectSmokeOverlay({super.key, required this.intensity});
  @override State<EffectSmokeOverlay> createState() => _EffectSmokeOverlayState();
}
class _EffectSmokeOverlayState extends State<EffectSmokeOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _SmokePainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _SmokePainter extends CustomPainter {
  final double t; final double intensity;
  _SmokePainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(99);
    for (int i = 0; i < (intensity * 8).toInt(); i++) {
      final progress = (t + i * 0.15) % 1.0;
      final x = size.width * (0.3 + rng.nextDouble() * 0.4) + sin(progress * 2 * pi) * 20;
      final y = size.height * (1 - progress * 1.2);
      final r = 20 + progress * 60;
      final alpha = (1 - progress) * 0.15 * intensity;
      canvas.drawCircle(Offset(x, y), r, Paint()..color = Colors.white.withOpacity(alpha)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));
    }
  }
  @override bool shouldRepaint(_SmokePainter old) => old.t != t;
}

// ── Ink Drop ──────────────────────────────────────────────────────────────────
class EffectInkDropOverlay extends StatefulWidget {
  final double intensity;
  const EffectInkDropOverlay({super.key, required this.intensity});
  @override State<EffectInkDropOverlay> createState() => _EffectInkDropOverlayState();
}
class _EffectInkDropOverlayState extends State<EffectInkDropOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _InkDropPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _InkDropPainter extends CustomPainter {
  final double t; final double intensity;
  _InkDropPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(77);
    final colors = [const Color(0xFF311B92), const Color(0xFF4527A0), const Color(0xFF7B1FA2)];
    for (int i = 0; i < (intensity * 5).toInt(); i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final phase = (t + i * 0.25) % 1.0;
      final r = phase * 60;
      final alpha = (1 - phase) * 0.3 * intensity;
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = colors[i % colors.length].withOpacity(alpha)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }
  }
  @override bool shouldRepaint(_InkDropPainter old) => old.t != t;
}

// ── Crystal ───────────────────────────────────────────────────────────────────
class EffectCrystalOverlay extends StatefulWidget {
  final double intensity;
  const EffectCrystalOverlay({super.key, required this.intensity});
  @override State<EffectCrystalOverlay> createState() => _EffectCrystalOverlayState();
}
class _EffectCrystalOverlayState extends State<EffectCrystalOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _CrystalPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _CrystalPainter extends CustomPainter {
  final double t; final double intensity;
  _CrystalPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(33);
    for (int i = 0; i < (intensity * 10).toInt(); i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final r = 5 + rng.nextDouble() * 15;
      final angle = t * 2 * pi + i;
      final path = Path();
      for (int j = 0; j < 6; j++) {
        final a = angle + j * pi / 3;
        if (j == 0) path.moveTo(cx + cos(a) * r, cy + sin(a) * r);
        else path.lineTo(cx + cos(a) * r, cy + sin(a) * r);
      }
      path.close();
      final alpha = sin(t * 2 * pi + i * 0.5).abs() * 0.4 * intensity;
      canvas.drawPath(path, Paint()..color = const Color(0xFF80CBC4).withOpacity(alpha)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }
  @override bool shouldRepaint(_CrystalPainter old) => old.t != t;
}

// ── Fire ──────────────────────────────────────────────────────────────────────
class EffectFireOverlay extends StatefulWidget {
  final double intensity;
  const EffectFireOverlay({super.key, required this.intensity});
  @override State<EffectFireOverlay> createState() => _EffectFireOverlayState();
}
class _EffectFireOverlayState extends State<EffectFireOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _FirePainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _FirePainter extends CustomPainter {
  final double t; final double intensity;
  _FirePainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random((t * 500).toInt());
    for (int i = 0; i < (intensity * 30).toInt(); i++) {
      final x = rng.nextDouble() * size.width;
      final baseY = size.height;
      final h = (0.3 + rng.nextDouble() * 0.5) * size.height * intensity;
      final y = baseY - h * (0.5 + sin(t * 2 * pi + i * 0.3) * 0.5);
      final colors = [const Color(0xFFFF3D00), const Color(0xFFFF6D00), const Color(0xFFFFD600)];
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 8 + rng.nextDouble() * 16, height: 20 + rng.nextDouble() * 30),
          Paint()..color = colors[i % 3].withOpacity(0.4 * intensity)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
  }
  @override bool shouldRepaint(_FirePainter old) => old.t != t;
}

// ── TV Lines ──────────────────────────────────────────────────────────────────
class EffectTvLinesOverlay extends StatefulWidget {
  final double intensity;
  const EffectTvLinesOverlay({super.key, required this.intensity});
  @override State<EffectTvLinesOverlay> createState() => _EffectTvLinesOverlayState();
}
class _EffectTvLinesOverlayState extends State<EffectTvLinesOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _TvLinesPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _TvLinesPainter extends CustomPainter {
  final double t; final double intensity;
  _TvLinesPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 2;
    for (int i = 0; i < 6; i++) {
      final y = (t * size.height * 1.5 + i * size.height / 6) % (size.height + 20) - 10;
      paint.color = const Color(0xFF546E7A).withOpacity(0.4 * intensity);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF546E7A).withOpacity(0.04 * intensity));
  }
  @override bool shouldRepaint(_TvLinesPainter old) => old.t != t;
}

// ── Lens Flare ────────────────────────────────────────────────────────────────
class EffectLensFlareOverlay extends StatefulWidget {
  final double intensity;
  const EffectLensFlareOverlay({super.key, required this.intensity});
  @override State<EffectLensFlareOverlay> createState() => _EffectLensFlareOverlayState();
}
class _EffectLensFlareOverlayState extends State<EffectLensFlareOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _LensFlarePainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _LensFlarePainter extends CustomPainter {
  final double t; final double intensity;
  _LensFlarePainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.7; final cy = size.height * 0.2;
    final radii = [80.0, 50.0, 30.0, 15.0];
    for (int i = 0; i < radii.length; i++) {
      final alpha = (0.3 + sin(t * pi + i) * 0.15) * intensity;
      canvas.drawCircle(Offset(cx, cy), radii[i], Paint()..color = const Color(0xFFFFFDE7).withOpacity(alpha)..maskFilter = MaskFilter.blur(BlurStyle.normal, radii[i] * 0.5));
    }
    final streak = Paint()..color = Colors.white.withOpacity(0.15 * intensity)..strokeWidth = 2..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawLine(Offset(cx - 100, cy), Offset(cx + 100, cy), streak);
    canvas.drawLine(Offset(cx, cy - 60), Offset(cx, cy + 60), streak);
  }
  @override bool shouldRepaint(_LensFlarePainter old) => old.t != t;
}
// ── Heat Wave ─────────────────────────────────────────────────────────────────
class EffectHeatWaveOverlay extends StatefulWidget {
  final double intensity;
  const EffectHeatWaveOverlay({super.key, required this.intensity});
  @override State<EffectHeatWaveOverlay> createState() => _EffectHeatWaveOverlayState();
}
class _EffectHeatWaveOverlayState extends State<EffectHeatWaveOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _HeatWavePainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _HeatWavePainter extends CustomPainter {
  final double t; final double intensity;
  _HeatWavePainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 8; i++) {
      final y = size.height * (i / 8.0);
      final waveOffset = sin(t * 2 * pi + i * 0.7) * 6 * intensity;
      final paint = Paint()
        ..color = Colors.orange.withOpacity(0.04 * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRect(Rect.fromLTWH(waveOffset, y, size.width, size.height / 8), paint);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFFF6E40).withOpacity(0.04 * intensity),
    );
  }
  @override bool shouldRepaint(_HeatWavePainter old) => old.t != t;
}

// ── Pixel Sort ────────────────────────────────────────────────────────────────
class EffectPixelSortOverlay extends StatefulWidget {
  final double intensity;
  const EffectPixelSortOverlay({super.key, required this.intensity});
  @override State<EffectPixelSortOverlay> createState() => _EffectPixelSortOverlayState();
}
class _EffectPixelSortOverlayState extends State<EffectPixelSortOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _PixelSortPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _PixelSortPainter extends CustomPainter {
  final double t; final double intensity;
  _PixelSortPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random((t * 200).toInt());
    for (int i = 0; i < (intensity * 12).toInt(); i++) {
      final y = rng.nextDouble() * size.height;
      final x = rng.nextDouble() * size.width * 0.5;
      final w = rng.nextDouble() * size.width * 0.6 * intensity;
      final hue = rng.nextDouble() * 360;
      canvas.drawRect(
        Rect.fromLTWH(x, y, w, 2 + rng.nextDouble() * 3),
        Paint()..color = HSVColor.fromAHSV(0.6 * intensity, hue, 1.0, 1.0).toColor(),
      );
    }
  }
  @override bool shouldRepaint(_PixelSortPainter old) => old.t != t;
}

// ── Light Leak ────────────────────────────────────────────────────────────────
class EffectLightLeakOverlay extends StatefulWidget {
  final double intensity;
  const EffectLightLeakOverlay({super.key, required this.intensity});
  @override State<EffectLightLeakOverlay> createState() => _EffectLightLeakOverlayState();
}
class _EffectLightLeakOverlayState extends State<EffectLightLeakOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => CustomPaint(painter: _LightLeakPainter(t: _ctrl.value, intensity: widget.intensity)),
  );
}
class _LightLeakPainter extends CustomPainter {
  final double t; final double intensity;
  _LightLeakPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final leak1 = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFFFD180).withOpacity(0.45 * intensity * (0.5 + t * 0.5)),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: Offset.zero, radius: size.width * 0.7));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), leak1);
    final leak2 = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFFF6D00).withOpacity(0.35 * intensity * (1 - t * 0.5)),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: Offset(size.width, size.height), radius: size.width * 0.6));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), leak2);
  }
  @override bool shouldRepaint(_LightLeakPainter old) => old.t != t;
}

// ── Vaporwave ─────────────────────────────────────────────────────────────────
class EffectVaporwaveOverlay extends StatefulWidget {
  final double intensity;
  const EffectVaporwaveOverlay({super.key, required this.intensity});
  @override State<EffectVaporwaveOverlay> createState() => _EffectVaporwaveOverlayState();
}
class _EffectVaporwaveOverlayState extends State<EffectVaporwaveOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _VaporwavePainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _VaporwavePainter extends CustomPainter {
  final double t; final double intensity;
  _VaporwavePainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFEA80FC).withOpacity(0.18 * intensity),
          const Color(0xFF40C4FF).withOpacity(0.12 * intensity),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    final horizon = size.height * 0.55;
    final paint = Paint()..strokeWidth = 1;
    for (int i = 1; i <= 6; i++) {
      final progress = i / 6.0;
      final y = horizon + (size.height - horizon) * progress;
      final animY = (y + t * (size.height - horizon) * 0.3) % (size.height - horizon) + horizon;
      paint.color = const Color(0xFFEA80FC).withOpacity(0.35 * intensity * progress);
      canvas.drawLine(Offset(0, animY), Offset(size.width, animY), paint);
    }
    for (int i = -3; i <= 3; i++) {
      final vanishX = size.width / 2;
      final bottomX = vanishX + i * size.width * 0.18;
      paint.color = const Color(0xFF40C4FF).withOpacity(0.3 * intensity);
      canvas.drawLine(Offset(vanishX, horizon), Offset(bottomX, size.height), paint);
    }
  }
  @override bool shouldRepaint(_VaporwavePainter old) => old.t != t;
}

// ── Bokeh ─────────────────────────────────────────────────────────────────────
class EffectBokehOverlay extends StatefulWidget {
  final double intensity;
  const EffectBokehOverlay({super.key, required this.intensity});
  @override State<EffectBokehOverlay> createState() => _EffectBokehOverlayState();
}
class _EffectBokehOverlayState extends State<EffectBokehOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _BokehPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _BokehPainter extends CustomPainter {
  final double t; final double intensity;
  _BokehPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(44);
    final colors = [
      const Color(0xFFFFECB3), const Color(0xFFB3E5FC),
      const Color(0xFFE1BEE7), const Color(0xFFC8E6C9),
    ];
    for (int i = 0; i < (intensity * 18).toInt(); i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final r = 12 + rng.nextDouble() * 28;
      final alpha = sin((t * 2 * pi + i * 0.4) % (2 * pi)).abs() * 0.35 * intensity;
      canvas.drawCircle(Offset(cx, cy), r,
          Paint()
            ..color = colors[i % colors.length].withOpacity(alpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6));
      canvas.drawCircle(Offset(cx, cy), r,
          Paint()
            ..color = Colors.white.withOpacity(alpha * 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }
  @override bool shouldRepaint(_BokehPainter old) => old.t != t;
}

// ── Warp Speed ────────────────────────────────────────────────────────────────
class EffectWarpSpeedOverlay extends StatefulWidget {
  final double intensity;
  const EffectWarpSpeedOverlay({super.key, required this.intensity});
  @override State<EffectWarpSpeedOverlay> createState() => _EffectWarpSpeedOverlayState();
}
class _EffectWarpSpeedOverlayState extends State<EffectWarpSpeedOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _WarpSpeedPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _WarpSpeedPainter extends CustomPainter {
  final double t; final double intensity;
  _WarpSpeedPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    final rng = Random(55);
    for (int i = 0; i < (intensity * 60).toInt(); i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final startR = rng.nextDouble() * 20 + t * size.width * 0.6;
      final endR = startR + 15 + t * 40 * intensity;
      if (startR > size.width) continue;
      final alpha = (1 - startR / size.width).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(cx + cos(angle) * startR, cy + sin(angle) * startR),
        Offset(cx + cos(angle) * endR, cy + sin(angle) * endR),
        Paint()
          ..color = Colors.white.withOpacity(alpha * intensity)
          ..strokeWidth = 0.8 + rng.nextDouble() * 1.5,
      );
    }
  }
  @override bool shouldRepaint(_WarpSpeedPainter old) => old.t != t;
}

// ── Glitter ───────────────────────────────────────────────────────────────────
class EffectGlitterOverlay extends StatefulWidget {
  final double intensity;
  const EffectGlitterOverlay({super.key, required this.intensity});
  @override State<EffectGlitterOverlay> createState() => _EffectGlitterOverlayState();
}
class _EffectGlitterOverlayState extends State<EffectGlitterOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _GlitterPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _GlitterPainter extends CustomPainter {
  final double t; final double intensity;
  _GlitterPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random((t * 50000).toInt());
    for (int i = 0; i < (intensity * 120).toInt(); i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final bright = rng.nextDouble();
      if (bright > 0.6) {
        final r = 2 + rng.nextDouble() * 4;
        final p = Paint()
          ..color = Color.lerp(const Color(0xFFFFD54F), Colors.white, bright)!
              .withOpacity(bright * intensity)
          ..strokeWidth = 1;
        canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), p);
        canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), p);
        canvas.drawLine(Offset(cx - r * 0.5, cy - r * 0.5), Offset(cx + r * 0.5, cy + r * 0.5), p..strokeWidth = 0.7);
        canvas.drawLine(Offset(cx + r * 0.5, cy - r * 0.5), Offset(cx - r * 0.5, cy + r * 0.5), p);
      }
    }
  }
  @override bool shouldRepaint(_GlitterPainter old) => old.t != t;
}

// ── Cinematic ─────────────────────────────────────────────────────────────────
class EffectCinematicOverlay extends StatefulWidget {
  final double intensity;
  const EffectCinematicOverlay({super.key, required this.intensity});
  @override State<EffectCinematicOverlay> createState() => _EffectCinematicOverlayState();
}
class _EffectCinematicOverlayState extends State<EffectCinematicOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _ctrl.forward();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => LayoutBuilder(builder: (_, constraints) {
      final barH = constraints.maxHeight * 0.10 * widget.intensity * _ctrl.value;
      return Stack(children: [
        Positioned(top: 0, left: 0, right: 0, child: Container(height: barH, color: Colors.black)),
        Positioned(bottom: 0, left: 0, right: 0, child: Container(height: barH, color: Colors.black)),
        Container(color: Colors.black.withOpacity(0.08 * widget.intensity)),
      ]);
    }),
  );
}

// ── Comic Pop Art ─────────────────────────────────────────────────────────────
class EffectComicOverlay extends StatefulWidget {
  final double intensity;
  const EffectComicOverlay({super.key, required this.intensity});
  @override State<EffectComicOverlay> createState() => _EffectComicOverlayState();
}
class _EffectComicOverlayState extends State<EffectComicOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _ComicPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _ComicPainter extends CustomPainter {
  final double t; final double intensity;
  _ComicPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final dotSpacing = 10.0 - intensity * 3;
    final rng = Random(12);
    for (double x = 0; x < size.width; x += dotSpacing) {
      for (double y = 0; y < size.height; y += dotSpacing) {
        final maxR = dotSpacing * 0.45;
        final r = maxR * (0.3 + rng.nextDouble() * 0.5) * intensity;
        canvas.drawCircle(Offset(x, y), r, Paint()..color = Colors.black.withOpacity(0.08 * intensity));
      }
    }
    final flashAlpha = sin(t * 2 * pi).abs() * 0.06 * intensity;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFFFFF00).withOpacity(flashAlpha),
    );
  }
  @override bool shouldRepaint(_ComicPainter old) => old.t != t;
}

// ── Neon Trails ───────────────────────────────────────────────────────────────
class EffectNeonTrailsOverlay extends StatefulWidget {
  final double intensity;
  const EffectNeonTrailsOverlay({super.key, required this.intensity});
  @override State<EffectNeonTrailsOverlay> createState() => _EffectNeonTrailsOverlayState();
}
class _EffectNeonTrailsOverlayState extends State<EffectNeonTrailsOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _NeonTrailsPainter(t: _ctrl.value, intensity: widget.intensity)));
}
class _NeonTrailsPainter extends CustomPainter {
  final double t; final double intensity;
  _NeonTrailsPainter({required this.t, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final colors = [const Color(0xFF18FFFF), const Color(0xFFE040FB), const Color(0xFF76FF03)];
    final rng = Random(66);
    for (int i = 0; i < (intensity * 5).toInt(); i++) {
      final progress = (t + i * 0.25) % 1.0;
      final color = colors[i % colors.length];
      final path = Path();
      final startX = rng.nextDouble() * size.width;
      path.moveTo(startX, size.height);
      for (int j = 0; j < 8; j++) {
        final px = startX + sin(progress * 2 * pi + j * 0.5 + i) * 30 * intensity;
        final py = size.height * (1 - (j / 8.0) * progress);
        path.lineTo(px, py);
      }
      canvas.drawPath(path, Paint()
        ..color = color.withOpacity((1 - progress) * 0.6 * intensity)
        ..strokeWidth = 2 + intensity * 2
        ..style = PaintingStyle.stroke
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + intensity * 3));
    }
  }
  @override bool shouldRepaint(_NeonTrailsPainter old) => old.t != t;
}
// ════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET UI
// ════════════════════════════════════════════════════════════════════════════

class EffectBottomSheet extends StatefulWidget {
  final bool isVideo;
  final double videoDuration;
  final List<EffectLayer> initialLayers;
  final void Function(List<EffectLayer> layers) onDone;

  const EffectBottomSheet({
    super.key,
    required this.isVideo,
    this.videoDuration = 10.0,
    this.initialLayers = const [],
    required this.onDone,
  });

  @override
  State<EffectBottomSheet> createState() => _EffectBottomSheetState();
}

class _EffectBottomSheetState extends State<EffectBottomSheet> with SingleTickerProviderStateMixin {
  final List<String> _categories = ['⚡ Visual', '📼 Retro', '🌿 Nature', '🎉 Party', '🔮 Aesthetic'];
  int _catIndex = 0;
  late List<EffectLayer> _layers;
  int? _selectedLayerIndex;

  @override
  void initState() {
    super.initState();
    _layers = List.from(widget.initialLayers.map((l) => EffectLayer(id: l.id, effectKey: l.effectKey, intensity: l.intensity, startSec: l.startSec, endSec: l.endSec)));
  }

  List<EffectDef> get _currentEffects => kAllEffects.where((e) => e.category == _categories[_catIndex]).toList();
  bool _isApplied(String key) => _layers.any((l) => l.effectKey == key);

  void _toggleEffect(EffectDef def) {
    setState(() {
      final idx = _layers.indexWhere((l) => l.effectKey == def.key);
      if (idx >= 0) {
        _layers.removeAt(idx);
        if (_selectedLayerIndex == idx) _selectedLayerIndex = null;
      } else {
        _layers.add(EffectLayer(id: '${def.key}_${DateTime.now().millisecondsSinceEpoch}', effectKey: def.key, endSec: widget.videoDuration));
        _selectedLayerIndex = _layers.length - 1;
      }
    });
  }

  void _removeLayer(int index) {
    setState(() {
      _layers.removeAt(index);
      if (_selectedLayerIndex == index) _selectedLayerIndex = null;
      else if (_selectedLayerIndex != null && _selectedLayerIndex! > index) _selectedLayerIndex = _selectedLayerIndex! - 1;
    });
  }

  EffectDef _defFor(String key) => kAllEffects.firstWhere((e) => e.key == key, orElse: () => kAllEffects.first);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(color: Color(0xFF111111), borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      child: Column(children: [
        _buildHandle(),
        _buildHeader(),
        _buildCategoryTabs(),
        _buildEffectGrid(),
        if (_layers.isNotEmpty) _buildLayerStrip(),
        if (_selectedLayerIndex != null) _buildIntensitySlider(),
        if (_selectedLayerIndex != null && widget.isVideo) _buildTimeline(),
        _buildDoneCancel(),
      ]),
    );
  }

  Widget _buildHandle() => Container(margin: const EdgeInsets.only(top: 10, bottom: 4), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)));

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(children: [
      const Text('Effects', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const Spacer(),
      if (_layers.isNotEmpty)
        GestureDetector(
          onTap: () => setState(() { _layers.clear(); _selectedLayerIndex = null; }),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.5))),
              child: const Row(children: [Icon(Icons.undo, color: Colors.red, size: 14), SizedBox(width: 4), Text('Undo All', style: TextStyle(color: Colors.red, fontSize: 12))])),
        ),
    ]),
  );

  Widget _buildCategoryTabs() => SizedBox(
    height: 38,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _categories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        final sel = i == _catIndex;
        return GestureDetector(
          onTap: () => setState(() => _catIndex = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(color: sel ? Colors.white : Colors.white10, borderRadius: BorderRadius.circular(20)),
            child: Text(_categories[i], style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal, color: sel ? Colors.black : Colors.white70)),
          ),
        );
      },
    ),
  );

  Widget _buildEffectGrid() => Expanded(
    child: GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.82),
      itemCount: _currentEffects.length,
      itemBuilder: (context, i) => _EffectTile(def: _currentEffects[i], isApplied: _isApplied(_currentEffects[i].key), onTap: () => _toggleEffect(_currentEffects[i])),
    ),
  );

  Widget _buildLayerStrip() => Container(
    height: 60, margin: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(children: [
      const Text('Layers', style: TextStyle(color: Colors.white54, fontSize: 11)),
      const SizedBox(width: 10),
      Expanded(child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _layers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final layer = _layers[i]; final def = _defFor(layer.effectKey); final sel = _selectedLayerIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedLayerIndex = sel ? null : i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: sel ? def.accentColor.withOpacity(0.3) : Colors.white10, borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? def.accentColor : Colors.white24)),
              child: Row(children: [
                Icon(def.icon, color: def.accentColor, size: 16),
                const SizedBox(width: 5),
                Text(def.label, style: TextStyle(color: sel ? Colors.white : Colors.white70, fontSize: 11)),
                const SizedBox(width: 6),
                GestureDetector(onTap: () => _removeLayer(i), child: const Icon(Icons.close, color: Colors.red, size: 14)),
              ]),
            ),
          );
        },
      )),
    ]),
  );

  Widget _buildIntensitySlider() {
    final layer = _layers[_selectedLayerIndex!]; final def = _defFor(layer.effectKey);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(def.icon, color: def.accentColor, size: 14),
          const SizedBox(width: 6),
          Text('${def.label} Intensity', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const Spacer(),
          Text('${(layer.intensity * 100).toInt()}%', style: TextStyle(color: def.accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
        SliderTheme(
          data: SliderThemeData(activeTrackColor: def.accentColor, inactiveTrackColor: Colors.white12, thumbColor: def.accentColor, overlayColor: def.accentColor.withOpacity(0.2), trackHeight: 3),
          child: Slider(value: layer.intensity, onChanged: (v) => setState(() => layer.intensity = v)),
        ),
      ]),
    );
  }

  Widget _buildTimeline() {
    final layer = _layers[_selectedLayerIndex!]; final def = _defFor(layer.effectKey);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.timeline, color: Colors.white54, size: 14),
          const SizedBox(width: 6),
          const Text('Effect Timeline', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const Spacer(),
          Text('${layer.startSec.toStringAsFixed(1)}s → ${layer.endSec.toStringAsFixed(1)}s', style: TextStyle(color: def.accentColor, fontSize: 11)),
        ]),
        RangeSlider(
          values: RangeValues(layer.startSec, layer.endSec),
          min: 0, max: widget.videoDuration,
          divisions: (widget.videoDuration * 10).toInt().clamp(1, 1000),
          activeColor: def.accentColor, inactiveColor: Colors.white12,
          onChanged: (rv) => setState(() { layer.startSec = rv.start; layer.endSec = rv.end; }),
        ),
      ]),
    );
  }

  Widget _buildDoneCancel() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
    child: Row(children: [
      Expanded(child: OutlinedButton(
        onPressed: () => Navigator.pop(context),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24), foregroundColor: Colors.white70, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 13)),
        child: const Text('Cancel'),
      )),
      const SizedBox(width: 12),
      Expanded(flex: 2, child: ElevatedButton(
        onPressed: () { Navigator.pop(context); widget.onDone(_layers); },
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4458), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 13)),
        child: Text(_layers.isEmpty ? 'Done' : 'Apply ${_layers.length} Effect${_layers.length > 1 ? 's' : ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
      )),
    ]),
  );
}

// ── Effect Tile ───────────────────────────────────────────────────────────────

class _EffectTile extends StatefulWidget {
  final EffectDef def;
  final bool isApplied;
  final VoidCallback onTap;
  const _EffectTile({required this.def, required this.isApplied, required this.onTap});
  @override State<_EffectTile> createState() => _EffectTileState();
}
class _EffectTileState extends State<_EffectTile> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  @override void initState() { super.initState(); _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true); }
  @override void dispose() { _anim.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: widget.isApplied ? def.accentColor.withOpacity(0.25) : Colors.white10,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.isApplied ? def.accentColor : Colors.white12, width: widget.isApplied ? 1.5 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          _AnimatedPreview(anim: _anim, def: def, isApplied: widget.isApplied),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(def.label, style: TextStyle(color: widget.isApplied ? def.accentColor : Colors.white70, fontSize: 9, fontWeight: widget.isApplied ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (widget.isApplied) Icon(Icons.check_circle, color: def.accentColor, size: 10),
        ]),
      ),
    );
  }
}

// ── Animated Preview ──────────────────────────────────────────────────────────

class _AnimatedPreview extends StatelessWidget {
  final AnimationController anim;
  final EffectDef def;
  final bool isApplied;
  const _AnimatedPreview({required this.anim, required this.def, required this.isApplied});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 42, height: 42,
    child: AnimatedBuilder(animation: anim, builder: (_, __) => _buildPreview(def.key, anim.value, def.accentColor)),
  );

  Widget _buildPreview(String key, double t, Color color) {
    switch (key) {
      case 'glitch':       return _GlitchPrev(t: t, color: color);
      case 'mirror':       return _MirrorPrev(t: t, color: color);
      case 'rgb':          return _RgbPrev(t: t);
      case 'pixelate':     return _PixelatePrev(t: t, color: color);
      case 'shake':        return _ShakePrev(t: t, color: color);
      case 'zoom_pulse':   return _ZoomPulsePrev(t: t, color: color);
      case 'color_shift':  return _ColorShiftPrev(t: t);
      case 'invert':       return _InvertPrev(t: t, color: color);
      case 'scanline':     return _ScanlinePrev(t: t, color: color);
      case 'edge_glow':    return _EdgeGlowPrev(t: t, color: color);
      case 'kaleidoscope': return _KaleidoscopePrev(t: t, color: color);
      case 'fisheye':      return _FisheyePrev(t: t, color: color);
      case 'vhs':          return _VhsPrev(t: t, color: color);
      case 'film_grain':   return _FilmGrainPrev(t: t, color: color);
      case 'crt':          return _CrtPrev(t: t, color: color);
      case 'vignette':     return _VignettePrev(t: t, color: color);
      case 'retro_wave':   return _RetroWavePrev(t: t, color: color);
      case 'duotone':      return _DuotonePrev(t: t, color: color);
      case 'hologram':     return _HologramPrev(t: t, color: color);
      case 'noise_static': return _NoiseStaticPrev(t: t, color: color);
      case 'rain':         return _RainPrev(t: t);
      case 'snow':         return _SnowPrev(t: t);
      case 'fireflies':    return _FirefliesPrev(t: t, color: color);
      case 'petals':       return _PetalsPrev(t: t, color: color);
      case 'aurora':       return _AuroraPrev(t: t, color: color);
      case 'fog':          return _FogPrev(t: t, color: color);
      case 'lightning':    return _LightningPrev(t: t, color: color);
      case 'underwater':   return _UnderwaterPrev(t: t, color: color);
      case 'stars':        return _StarsPrev(t: t, color: color);
      case 'lensflare':    return _LensFlarePrev(t: t, color: color);
      case 'sparkle':      return _SparklePrev(t: t);
      case 'neon':         return _NeonPrev(t: t, color: color);
      case 'confetti':     return _ConfettiPrev(t: t, color: color);
      case 'disco':        return _DiscoPrev(t: t);
      case 'laser':        return _LaserPrev(t: t, color: color);
      case 'hearts':       return _HeartsPrev(t: t, color: color);
      case 'bubbles':      return _BubblesPrev(t: t, color: color);
      case 'explosion':    return _ExplosionPrev(t: t, color: color);
      case 'rainbow':      return _RainbowPrev(t: t);
      case 'matrix':       return _MatrixPrev(t: t, color: color);
      case 'dreamy':       return _DreamyPrev(t: t, color: color);
      case 'lofi':         return _LofiPrev(t: t, color: color);
      case 'prism':        return _PrismPrev(t: t, color: color);
      case 'glimmer':      return _GlimmerPrev(t: t, color: color);
      case 'portal':       return _PortalPrev(t: t, color: color);
      case 'smoke':        return _SmokePrev(t: t, color: color);
      case 'ink_drop':     return _InkDropPrev(t: t, color: color);
      case 'crystal':      return _CrystalPrev(t: t, color: color);
      case 'fire':         return _FirePrev(t: t, color: color);
      case 'tv_lines':     return _TvLinesPrev(t: t, color: color);
      default:             return Icon(def.icon, color: color.withOpacity(0.5 + t * 0.5), size: 26);
    }
  }
}

// ── Preview Widgets (compact) ─────────────────────────────────────────────────

class _GlitchPrev extends StatelessWidget {
  final double t; final Color color;
  const _GlitchPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Stack(alignment: Alignment.center, children: [
    Transform.translate(offset: Offset((t - 0.5) * 8, 0), child: Icon(Icons.error_outline, color: Colors.red.withOpacity(0.7), size: 26)),
    Transform.translate(offset: Offset(-(t - 0.5) * 8, 0), child: Icon(Icons.error_outline, color: Colors.blue.withOpacity(0.7), size: 26)),
    Icon(Icons.error_outline, color: color, size: 26),
  ]);
}

class _MirrorPrev extends StatelessWidget {
  final double t; final Color color;
  const _MirrorPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.person, color: color, size: 20),
    Transform(alignment: Alignment.centerLeft, transform: Matrix4.rotationY(pi), child: Icon(Icons.person, color: color.withOpacity(0.6), size: 20)),
  ]);
}

class _RgbPrev extends StatelessWidget {
  final double t;
  const _RgbPrev({required this.t});
  @override Widget build(BuildContext context) => Stack(alignment: Alignment.center, children: [
    Transform.translate(offset: Offset(-t * 6, 0), child: const Icon(Icons.circle, color: Colors.red, size: 18)),
    const Icon(Icons.circle, color: Colors.green, size: 18),
    Transform.translate(offset: Offset(t * 6, 0), child: const Icon(Icons.circle, color: Colors.blue, size: 18)),
  ]);
}

class _PixelatePrev extends StatelessWidget {
  final double t; final Color color;
  const _PixelatePrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _PixelPainter(blockSize: 4 + t * 8, color: color, t: t));
}
class _PixelPainter extends CustomPainter {
  final double blockSize; final Color color; final double t;
  _PixelPainter({required this.blockSize, required this.color, required this.t});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    for (double x = 0; x < size.width; x += blockSize) for (double y = 0; y < size.height; y += blockSize) canvas.drawRect(Rect.fromLTWH(x, y, blockSize - 1, blockSize - 1), Paint()..color = color.withOpacity(0.3 + rng.nextDouble() * 0.5));
  }
  @override bool shouldRepaint(_PixelPainter old) => old.blockSize != blockSize;
}

class _ShakePrev extends StatelessWidget {
  final double t; final Color color;
  const _ShakePrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Transform.translate(offset: Offset(sin(t * pi * 4) * 4, 0), child: Icon(Icons.shutter_speed, color: color, size: 26));
}

class _ZoomPulsePrev extends StatelessWidget {
  final double t; final Color color;
  const _ZoomPulsePrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Transform.scale(scale: 0.8 + t * 0.4, child: Icon(Icons.zoom_in, color: color, size: 26));
}

class _ColorShiftPrev extends StatelessWidget {
  final double t;
  const _ColorShiftPrev({required this.t});
  @override Widget build(BuildContext context) => Icon(Icons.color_lens, color: HSVColor.fromAHSV(1.0, t * 360, 1.0, 1.0).toColor(), size: 26);
}

class _InvertPrev extends StatelessWidget {
  final double t; final Color color;
  const _InvertPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Icon(Icons.invert_colors, color: Color.lerp(color, Colors.white, t)!, size: 26);
}

class _ScanlinePrev extends StatelessWidget {
  final double t; final Color color;
  const _ScanlinePrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _SLPrev(color: color));
}
class _SLPrev extends CustomPainter {
  final Color color;
  _SLPrev({required this.color});
  @override void paint(Canvas canvas, Size size) { for (double y = 0; y < size.height; y += 3) canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()..color = color.withOpacity(0.3)..strokeWidth = 1); }
  @override bool shouldRepaint(_SLPrev old) => false;
}

class _EdgeGlowPrev extends StatelessWidget {
  final double t; final Color color;
  const _EdgeGlowPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(border: Border.all(color: color.withOpacity(t), width: 2 + t * 2), borderRadius: BorderRadius.circular(6)), child: Icon(Icons.flare, color: color.withOpacity(0.5 + t * 0.5), size: 22));
}

class _KaleidoscopePrev extends StatelessWidget {
  final double t; final Color color;
  const _KaleidoscopePrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _KPrev(t: t, color: color));
}
class _KPrev extends CustomPainter {
  final double t; final Color color;
  _KPrev({required this.t, required this.color});
  @override void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    for (int i = 0; i < 6; i++) {
      final a = i * pi / 3 + t * 2 * pi;
      canvas.drawLine(Offset(cx, cy), Offset(cx + cos(a) * 18, cy + sin(a) * 18), Paint()..color = color.withOpacity(0.6)..strokeWidth = 2);
    }
  }
  @override bool shouldRepaint(_KPrev old) => old.t != t;
}

class _FisheyePrev extends StatelessWidget {
  final double t; final Color color;
  const _FisheyePrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Icon(Icons.lens, color: color.withOpacity(0.5 + t * 0.5), size: 26);
}

class _VhsPrev extends StatelessWidget {
  final double t; final Color color;
  const _VhsPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _VhsP(t: t, color: color));
}
class _VhsP extends CustomPainter {
  final double t; final Color color;
  _VhsP({required this.t, required this.color});
  @override void paint(Canvas canvas, Size size) {
    canvas.drawLine(Offset(0, (t * size.height) % size.height), Offset(size.width, (t * size.height) % size.height), Paint()..color = color.withOpacity(0.5)..strokeWidth = 2);
    final tp = TextPainter(text: TextSpan(text: '▶VHS', style: TextStyle(color: color, fontSize: 9)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height / 2 - 5));
  }
  @override bool shouldRepaint(_VhsP old) => old.t != t;
}

class _FilmGrainPrev extends StatelessWidget {
  final double t; final Color color;
  const _FilmGrainPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Icon(Icons.grain, color: color.withOpacity(0.5 + t * 0.5), size: 26);
}

class _CrtPrev extends StatelessWidget {
  final double t; final Color color;
  const _CrtPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _CrtP(t: t, color: color));
}
class _CrtP extends CustomPainter {
  final double t; final Color color;
  _CrtP({required this.t, required this.color});
  @override void paint(Canvas canvas, Size size) {
    for (double y = 0; y < size.height; y += 3) canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()..color = color.withOpacity(0.25)..strokeWidth = 1);
    canvas.drawLine(Offset(0, (t * size.height) % size.height), Offset(size.width, (t * size.height) % size.height), Paint()..color = const Color(0xFF4CAF50).withOpacity(0.5)..strokeWidth = 3);
  }
  @override bool shouldRepaint(_CrtP old) => old.t != t;
}

class _VignettePrev extends StatelessWidget {
  final double t; final Color color;
  const _VignettePrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(gradient: RadialGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.6)]), borderRadius: BorderRadius.circular(6)), child: Icon(Icons.vignette, color: color, size: 22));
}

class _RetroWavePrev extends StatelessWidget {
  final double t; final Color color;
  const _RetroWavePrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _RWPrev(t: t));
}
class _RWPrev extends CustomPainter {
  final double t;
  _RWPrev({required this.t});
  @override void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) {
      final path = Path()..moveTo(0, size.height * 0.5 + i * 6);
      for (double x = 0; x < size.width; x += 3) path.lineTo(x, size.height * 0.5 + sin(x / 10 + t * 2 * pi) * 5 + i * 6);
      canvas.drawPath(path, Paint()..color = Color.lerp(const Color(0xFFFF0080), const Color(0xFF00FFFF), i / 3)!.withOpacity(0.7)..strokeWidth = 1.5..style = PaintingStyle.stroke);
    }
  }
  @override bool shouldRepaint(_RWPrev old) => old.t != t;
}

class _DuotonePrev extends StatelessWidget {
  final double t; final Color color;
  const _DuotonePrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF7B1FA2).withOpacity(0.7), const Color(0xFFFF4081).withOpacity(0.7)]), borderRadius: BorderRadius.circular(6)), child: Icon(Icons.tonality, color: Colors.white, size: 22));
}

class _HologramPrev extends StatelessWidget {
  final double t; final Color color;
  const _HologramPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Icon(Icons.view_in_ar, color: const Color(0xFF00E5FF).withOpacity(0.5 + t * 0.5), size: 26);
}

class _NoiseStaticPrev extends StatelessWidget {
  final double t; final Color color;
  const _NoiseStaticPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _NSPrev(t: t));
}
class _NSPrev extends CustomPainter {
  final double t;
  _NSPrev({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random((t * 10000).toInt());
    for (int i = 0; i < 80; i++) canvas.drawRect(Rect.fromLTWH(rng.nextDouble() * size.width, rng.nextDouble() * size.height, 2, 2), Paint()..color = (rng.nextDouble() > 0.5 ? Colors.white : Colors.black).withOpacity(rng.nextDouble() * 0.6));
  }
  @override bool shouldRepaint(_NSPrev old) => old.t != t;
}

class _RainPrev extends StatelessWidget {
  final double t;
  const _RainPrev({required this.t});
  @override Widget build(BuildContext context) => CustomPaint(painter: _RainP(t: t));
}
class _RainP extends CustomPainter {
  final double t;
  _RainP({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.blue.withOpacity(0.7)..strokeWidth = 1.2;
    final rng = Random(42);
    for (int i = 0; i < 10; i++) { final x = rng.nextDouble() * size.width; final y = (rng.nextDouble() * size.height + t * size.height * 1.5) % size.height; canvas.drawLine(Offset(x, y), Offset(x - 1, y + 8), p); }
  }
  @override bool shouldRepaint(_RainP old) => old.t != t;
}

class _SnowPrev extends StatelessWidget {
  final double t;
  const _SnowPrev({required this.t});
  @override Widget build(BuildContext context) => CustomPaint(painter: _SnowP(t: t));
}
class _SnowP extends CustomPainter {
  final double t;
  _SnowP({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.9);
    final rng = Random(7);
    for (int i = 0; i < 10; i++) { final x = (rng.nextDouble() * size.width + sin(t * pi + i) * 3); final y = (rng.nextDouble() * size.height + t * size.height * 1.2) % size.height; canvas.drawCircle(Offset(x, y), 1.8, p); }
  }
  @override bool shouldRepaint(_SnowP old) => old.t != t;
}

class _FirefliesPrev extends StatelessWidget {
  final double t; final Color color;
  const _FirefliesPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _FFPrev(t: t));
}
class _FFPrev extends CustomPainter {
  final double t;
  _FFPrev({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(77);
    for (int i = 0; i < 6; i++) {
      final alpha = sin((t * 2 * pi + i * 0.8) % (2 * pi)).abs();
      canvas.drawCircle(Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height), 2, Paint()..color = Colors.yellow.withOpacity(alpha * 0.9)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
  }
  @override bool shouldRepaint(_FFPrev old) => old.t != t;
}

class _PetalsPrev extends StatelessWidget {
  final double t; final Color color;
  const _PetalsPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Icon(Icons.local_florist, color: const Color(0xFFFF80AB).withOpacity(0.5 + t * 0.5), size: 26);
}

class _AuroraPrev extends StatelessWidget {
  final double t; final Color color;
  const _AuroraPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF00E676).withOpacity(0.5 + sin(t * pi) * 0.3), const Color(0xFF7C4DFF).withOpacity(0.3)]), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22));
}

class _FogPrev extends StatelessWidget {
  final double t; final Color color;
  const _FogPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Icon(Icons.blur_on, color: Colors.white.withOpacity(0.4 + t * 0.4), size: 26);
}

class _LightningPrev extends StatelessWidget {
  final double t; final Color color;
  const _LightningPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Icon(Icons.electric_bolt, color: Colors.yellow.withOpacity(0.3 + t * 0.7), size: 26);
}

class _UnderwaterPrev extends StatelessWidget {
  final double t; final Color color;
  const _UnderwaterPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF006064).withOpacity(0.5), const Color(0xFF00BCD4).withOpacity(0.3)]), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.pool, color: Colors.cyan, size: 22));
}

class _StarsPrev extends StatelessWidget {
  final double t; final Color color;
  const _StarsPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _StarsP(t: t));
}
class _StarsP extends CustomPainter {
  final double t;
  _StarsP({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(21);
    for (int i = 0; i < 15; i++) { final twinkle = sin(t * 2 * pi + i * 0.7).abs(); canvas.drawCircle(Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height), 1.2, Paint()..color = Colors.white.withOpacity(twinkle)); }
  }
  @override bool shouldRepaint(_StarsP old) => old.t != t;
}

class _LensFlarePrev extends StatelessWidget {
  final double t; final Color color;
  const _LensFlarePrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Icon(Icons.wb_sunny, color: const Color(0xFFFFC107).withOpacity(0.5 + t * 0.5), size: 26);
}

class _SparklePrev extends StatelessWidget {
  final double t;
  const _SparklePrev({required this.t});
  @override Widget build(BuildContext context) => CustomPaint(painter: _SparkP(t: t));
}
class _SparkP extends CustomPainter {
  final double t;
  _SparkP({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(13); final cx = size.width / 2; final cy = size.height / 2;
    for (int i = 0; i < 6; i++) { final angle = (i / 6) * 2 * pi + t * pi; final r = (8 + rng.nextDouble() * 10) * t; canvas.drawCircle(Offset(cx + cos(angle) * r, cy + sin(angle) * r), 1.5, Paint()..color = Colors.yellow.withOpacity(0.8 * t + 0.2)); }
  }
  @override bool shouldRepaint(_SparkP old) => old.t != t;
}

class _NeonPrev extends StatelessWidget {
  final double t; final Color color;
  const _NeonPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.4 + t * 0.5), blurRadius: 10 + t * 8, spreadRadius: 2 + t * 4)]), child: Icon(Icons.local_bar, color: color, size: 24));
}

class _ConfettiPrev extends StatelessWidget {
  final double t; final Color color;
  const _ConfettiPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _ConfP(t: t));
}
class _ConfP extends CustomPainter {
  final double t;
  _ConfP({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final colors = [Colors.red, Colors.blue, Colors.yellow, Colors.green];
    final rng = Random(88);
    for (int i = 0; i < 8; i++) { final x = rng.nextDouble() * size.width; final y = (rng.nextDouble() * size.height + t * size.height) % size.height; canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: 4, height: 6), Paint()..color = colors[i % 4].withOpacity(0.8)); }
  }
  @override bool shouldRepaint(_ConfP old) => old.t != t;
}

class _DiscoPrev extends StatelessWidget {
  final double t;
  const _DiscoPrev({required this.t});
  @override Widget build(BuildContext context) => Icon(Icons.music_note, color: HSVColor.fromAHSV(1.0, t * 360, 1.0, 1.0).toColor(), size: 26);
}

class _LaserPrev extends StatelessWidget {
  final double t; final Color color;
  const _LaserPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _LaserP(t: t));
}
class _LaserP extends CustomPainter {
  final double t;
  _LaserP({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final step = 10 + t * 8;
    for (double x = 0; x < size.width; x += step) canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()..color = const Color(0xFF76FF03).withOpacity(0.5)..strokeWidth = 1);
    for (double y = 0; y < size.height; y += step) canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()..color = const Color(0xFF76FF03).withOpacity(0.5)..strokeWidth = 1);
  }
  @override bool shouldRepaint(_LaserP old) => old.t != t;
}

class _HeartsPrev extends StatelessWidget {
  final double t; final Color color;
  const _HeartsPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Icon(Icons.favorite, color: const Color(0xFFFF1744).withOpacity(0.5 + t * 0.5), size: 26);
}

class _BubblesPrev extends StatelessWidget {
  final double t; final Color color;
  const _BubblesPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _BubP(t: t));
}
class _BubP extends CustomPainter {
  final double t;
  _BubP({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(55);
    for (int i = 0; i < 5; i++) { final x = rng.nextDouble() * size.width; final y = size.height - (t * size.height * 1.2 + i * 10) % (size.height + 10); canvas.drawCircle(Offset(x, y), 3 + rng.nextDouble() * 5, Paint()..color = const Color(0xFF40C4FF).withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 1.5); }
  }
  @override bool shouldRepaint(_BubP old) => old.t != t;
}

class _ExplosionPrev extends StatelessWidget {
  final double t; final Color color;
  const _ExplosionPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _ExpP(t: t));
}
class _ExpP extends CustomPainter {
  final double t;
  _ExpP({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    for (int i = 0; i < 8; i++) { final angle = i * pi / 4; final r = t * 18; canvas.drawLine(Offset(cx, cy), Offset(cx + cos(angle) * r, cy + sin(angle) * r), Paint()..color = Colors.orange.withOpacity(1 - t)..strokeWidth = 2); }
  }
  @override bool shouldRepaint(_ExpP old) => old.t != t;
}

class _RainbowPrev extends StatelessWidget {
  final double t;
  const _RainbowPrev({required this.t});
  @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(gradient: LinearGradient(colors: List.generate(7, (i) => HSVColor.fromAHSV(1.0, (i * 51.4 + t * 360) % 360, 1.0, 1.0).toColor()), begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(6)));
}

class _MatrixPrev extends StatelessWidget {
  final double t; final Color color;
  const _MatrixPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Icon(Icons.code, color: const Color(0xFF00E676).withOpacity(0.5 + t * 0.5), size: 26);
}

class _DreamyPrev extends StatelessWidget {
  final double t; final Color color;
  const _DreamyPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(gradient: RadialGradient(colors: [const Color(0xFFCE93D8).withOpacity(0.4 + t * 0.4), const Color(0xFF80DEEA).withOpacity(0.2)]), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.cloud, color: Colors.white, size: 22));
}

class _LofiPrev extends StatelessWidget {
  final double t; final Color color;
  const _LofiPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Icon(Icons.headphones, color: const Color(0xFFA5D6A7).withOpacity(0.5 + t * 0.5), size: 26);
}

class _PrismPrev extends StatelessWidget {
  final double t; final Color color;
  const _PrismPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _PrismP(t: t));
}
class _PrismP extends CustomPainter {
  final double t;
  _PrismP({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    for (int i = 0; i < 5; i++) { final angle = t * 2 * pi + i * pi / 5; canvas.drawLine(Offset(cx, cy), Offset(cx + cos(angle) * 18, cy + sin(angle) * 18), Paint()..color = HSVColor.fromAHSV(0.8, (i * 72 + t * 360) % 360, 1.0, 1.0).toColor()..strokeWidth = 1.5); }
  }
  @override bool shouldRepaint(_PrismP old) => old.t != t;
}

class _GlimmerPrev extends StatelessWidget {
  final double t; final Color color;
  const _GlimmerPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _GlimP(t: t));
}
class _GlimP extends CustomPainter {
  final double t;
  _GlimP({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final rng = Random(12);
    for (int i = 0; i < 4; i++) { final alpha = sin(((t + i * 0.2) % 1.0) * pi).clamp(0.0, 1.0); canvas.drawCircle(Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height), 5 + 3 * alpha, Paint()..color = Colors.white.withOpacity(alpha)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)); }
  }
  @override bool shouldRepaint(_GlimP old) => old.t != t;
}

class _PortalPrev extends StatelessWidget {
  final double t; final Color color;
  const _PortalPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _PrtP(t: t));
}
class _PrtP extends CustomPainter {
  final double t;
  _PrtP({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    for (int i = 1; i <= 3; i++) { canvas.drawCircle(Offset(cx, cy), i * 7.0, Paint()..color = const Color(0xFF1DE9B6).withOpacity(0.4 - i * 0.1)..style = PaintingStyle.stroke..strokeWidth = 1.5); }
  }
  @override bool shouldRepaint(_PrtP old) => old.t != t;
}

class _SmokePrev extends StatelessWidget {
  final double t; final Color color;
  const _SmokePrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Icon(Icons.cloud_queue, color: Colors.white.withOpacity(0.3 + t * 0.5), size: 26);
}

class _InkDropPrev extends StatelessWidget {
  final double t; final Color color;
  const _InkDropPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _IDP(t: t));
}
class _IDP extends CustomPainter {
  final double t;
  _IDP({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    canvas.drawCircle(Offset(cx, cy), t * 20, Paint()..color = const Color(0xFF311B92).withOpacity((1 - t) * 0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  }
  @override bool shouldRepaint(_IDP old) => old.t != t;
}

class _CrystalPrev extends StatelessWidget {
  final double t; final Color color;
  const _CrystalPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _CryP(t: t));
}
class _CryP extends CustomPainter {
  final double t;
  _CryP({required this.t});
  @override void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2; final r = 14.0;
    final path = Path();
    for (int j = 0; j < 6; j++) { final a = t * 2 * pi + j * pi / 3; if (j == 0) path.moveTo(cx + cos(a) * r, cy + sin(a) * r); else path.lineTo(cx + cos(a) * r, cy + sin(a) * r); }
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF80CBC4).withOpacity(0.6)..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }
  @override bool shouldRepaint(_CryP old) => old.t != t;
}

class _FirePrev extends StatelessWidget {
  final double t; final Color color;
  const _FirePrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => Icon(Icons.local_fire_department, color: Color.lerp(Colors.orange, Colors.red, t)!, size: 26);
}

class _TvLinesPrev extends StatelessWidget {
  final double t; final Color color;
  const _TvLinesPrev({required this.t, required this.color});
  @override Widget build(BuildContext context) => CustomPaint(painter: _TVP(t: t));
}
class _TVP extends CustomPainter {
  final double t;
  _TVP({required this.t});
  @override void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) { final y = (t * size.height + i * size.height / 3) % size.height; canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()..color = const Color(0xFF546E7A).withOpacity(0.6)..strokeWidth = 2); }
  }
  @override bool shouldRepaint(_TVP old) => old.t != t;
}