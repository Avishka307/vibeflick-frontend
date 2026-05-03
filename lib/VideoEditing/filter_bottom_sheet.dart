import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

// ============================================================
//  COLOR MATRIX PRESETS
// ============================================================

class FilterMatrices {
  static List<double> get identity => [
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static List<double> blend(List<double> target, double intensity) {
    final t = intensity / 100.0;
    final id = identity;
    return List.generate(20, (i) => id[i] + (target[i] - id[i]) * t);
  }

  static const List<double> natural    = [1.1,0.0,0.0,0,8, 0.0,1.0,0.0,0,4, 0.0,0.0,0.9,0,-4, 0.0,0.0,0.0,1,0];
  static const List<double> beauty     = [1.05,0.00,0.00,0,12, 0.00,0.95,0.00,0,6, 0.00,0.00,0.92,0,0, 0.00,0.00,0.00,1,0];
  static const List<double> fresh      = [0.95,0.00,0.00,0,0, 0.05,1.10,0.00,0,8, 0.00,0.00,0.95,0,0, 0.00,0.00,0.00,1,0];
  static const List<double> bright     = [1.1,0.0,0.0,0,15, 0.0,1.1,0.0,0,15, 0.0,0.0,1.1,0,15, 0.0,0.0,0.0,1,0];
  static const List<double> smooth     = [1.0,0.0,0.0,0,5, 0.0,0.9,0.1,0,5, 0.0,0.0,1.0,0,10, 0.0,0.0,0.0,1,0];
  static const List<double> soft       = [1.0,0.05,0.00,0,5, 0.0,1.00,0.05,0,5, 0.0,0.00,1.00,0,10, 0.0,0.00,0.00,1,0];
  static const List<double> kamakura   = [0.9,0.0,0.1,0,5, 0.0,1.0,0.0,0,5, 0.1,0.0,1.1,0,10, 0.0,0.0,0.0,1,0];
  static const List<double> mongKok    = [1.1,0.0,0.0,0,10, 0.0,0.9,0.0,0,0, 0.1,0.0,1.0,0,15, 0.0,0.0,0.0,1,0];
  static const List<double> coastal    = [0.85,0.05,0.10,0,5, 0.00,1.00,0.05,0,10, 0.05,0.05,1.10,0,15, 0.00,0.00,0.00,1,0];
  static const List<double> california = [1.15,0.00,0.00,0,10, 0.05,1.05,0.00,0,5, 0.00,0.00,0.85,0,-5, 0.00,0.00,0.00,1,0];
  static const List<double> spring     = [1.0,0.0,0.0,0,8, 0.0,1.1,0.0,0,8, 0.0,0.1,1.0,0,12, 0.0,0.0,0.0,1,0];
  static const List<double> midsummer  = [1.2,0.0,0.0,0,15, 0.0,1.1,0.0,0,10, 0.0,0.0,0.8,0,-10, 0.0,0.0,0.0,1,0];
  static const List<double> delicious  = [1.15,0.05,0.00,0,10, 0.00,1.05,0.00,0,5, 0.00,0.00,0.85,0,-5, 0.00,0.00,0.00,1,0];
  static const List<double> gourmet    = [1.1,0.0,0.0,0,8, 0.0,1.0,0.0,0,3, 0.0,0.0,0.8,0,0, 0.0,0.0,0.0,1,0];
  static const List<double> sweet      = [1.1,0.0,0.0,0,15, 0.0,0.9,0.1,0,10, 0.0,0.0,1.0,0,10, 0.0,0.0,0.0,1,0];
  static const List<double> vibrant    = [1.3,-0.1,-0.1,0,0, -0.1,1.3,-0.1,0,0, -0.1,-0.1,1.3,0,0, 0.0,0.0,0.0,1,0];
  static const List<double> classic    = [0.9,0.05,0.05,0,5, 0.05,0.9,0.05,0,5, 0.05,0.05,0.9,0,5, 0.0,0.0,0.0,1,0];
  static const List<double> retro      = [1.0,0.2,0.0,0,20, 0.0,0.9,0.1,0,10, 0.0,0.1,0.7,0,15, 0.0,0.0,0.0,1,0];
  static const List<double> vintage    = [0.9,0.1,0.1,0,20, 0.1,0.8,0.1,0,10, 0.0,0.1,0.7,0,15, 0.0,0.0,0.0,1,0];
  static const List<double> film       = [0.85,0.10,0.05,0,18, 0.05,0.85,0.10,0,12, 0.05,0.05,0.80,0,18, 0.00,0.00,0.00,1,0];
  static const List<double> dreamy     = [1.0,0.0,0.0,0,10, 0.0,0.9,0.1,0,10, 0.1,0.0,1.1,0,20, 0.0,0.0,0.0,1,0];
  static const List<double> moody      = [0.75,0.00,0.00,0,-5, 0.00,0.75,0.00,0,-5, 0.10,0.10,1.10,0,15, 0.00,0.00,0.00,1,0];
  static const List<double> urban      = [0.9,0.0,0.0,0,-8, 0.0,0.9,0.0,0,-8, 0.0,0.0,1.0,0,-8, 0.0,0.0,0.0,1,0];
  static const List<double> modern     = [1.05,-0.05,0.00,0,0, -0.05,1.05,0.00,0,0, 0.00,-0.05,1.10,0,5, 0.00,0.00,0.00,1,0];
  static const List<double> minimal    = [0.95,0.00,0.00,0,10, 0.00,0.95,0.00,0,10, 0.00,0.00,0.95,0,10, 0.00,0.00,0.00,1,0];
  static const List<double> bold       = [1.4,-0.1,-0.1,0,0, -0.1,1.3,-0.1,0,0, -0.1,-0.1,1.4,0,0, 0.0,0.0,0.0,1,0];
  static const List<double> elegant    = [0.85,0.05,0.10,0,5, 0.00,0.80,0.10,0,5, 0.10,0.00,1.00,0,15, 0.00,0.00,0.00,1,0];
  static const List<double> artistic   = [1.0,0.2,-0.1,0,0, -0.1,1.0,0.2,0,0, 0.2,-0.1,1.0,0,0, 0.0,0.0,0.0,1,0];
  static const List<double> cinematic  = [0.70,0.10,0.00,0,-10, 0.00,0.75,0.05,0,-5, 0.10,0.10,1.00,0,10, 0.00,0.00,0.00,1,0];
}

// ============================================================
//  FILTER PRESET MODEL
// ============================================================

class FilterPreset {
  final String name;
  final List<double> matrix;
  final String? assetThumb;

  const FilterPreset({
    required this.name,
    required this.matrix,
    this.assetThumb,
  });
}

// ============================================================
//  FILTER BOTTOM SHEET
// ============================================================

class FilterBottomSheet extends StatefulWidget {
  final File mediaFile;
  final bool isVideo;

  // ── Live preview callback — activity_selected_media.dart ට notify කරනවා
  final void Function(List<double> matrix)? onPreviewChanged;

  const FilterBottomSheet({
    super.key,
    required this.mediaFile,
    required this.isVideo,
    this.onPreviewChanged,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {

  FilterPreset? _selected;
  double _intensity = 100.0;

  final List<String> _categories = [
    'No Filter',
    'Portrait',
    'Scenery',
    'Food',
    'Vibes',
    'Style',
  ];
  int _catIndex = 1;

  late final Map<String, List<FilterPreset>> _allFilters = {
    'No Filter': [],
    'Portrait': [
      FilterPreset(name: 'Natural',  matrix: FilterMatrices.natural,    assetThumb: 'assets/images/filter_natural.jpg'),
      FilterPreset(name: 'Beauty',   matrix: FilterMatrices.beauty,     assetThumb: 'assets/images/filter_beauty.jpg'),
      FilterPreset(name: 'Fresh',    matrix: FilterMatrices.fresh,      assetThumb: 'assets/images/filter_fresh.jpg'),
      FilterPreset(name: 'Bright',   matrix: FilterMatrices.bright,     assetThumb: 'assets/images/filter_bright.jpg'),
      FilterPreset(name: 'Smooth',   matrix: FilterMatrices.smooth,     assetThumb: 'assets/images/filter_smooth.jpg'),
      FilterPreset(name: 'Soft',     matrix: FilterMatrices.soft,       assetThumb: 'assets/images/filter_soft.jpg'),
    ],
    'Scenery': [
      FilterPreset(name: 'Kamakura',   matrix: FilterMatrices.kamakura,   assetThumb: 'assets/images/filter_kamakura.jpg'),
      FilterPreset(name: 'Mong Kok',   matrix: FilterMatrices.mongKok,    assetThumb: 'assets/images/filter_mongkok.jpg'),
      FilterPreset(name: 'Coastal',    matrix: FilterMatrices.coastal,    assetThumb: 'assets/images/filter_coastal.jpg'),
      FilterPreset(name: 'California', matrix: FilterMatrices.california, assetThumb: 'assets/images/filter_california.jpg'),
      FilterPreset(name: 'Spring',     matrix: FilterMatrices.spring,     assetThumb: 'assets/images/filter_spring.jpg'),
      FilterPreset(name: 'Midsummer',  matrix: FilterMatrices.midsummer,  assetThumb: 'assets/images/filter_midsummer.jpg'),
    ],
    'Food': [
      FilterPreset(name: 'Delicious', matrix: FilterMatrices.delicious, assetThumb: 'assets/images/filter_delicious.jpg'),
      FilterPreset(name: 'Gourmet',   matrix: FilterMatrices.gourmet,   assetThumb: 'assets/images/filter_gourmet.jpg'),
      FilterPreset(name: 'Sweet',     matrix: FilterMatrices.sweet,     assetThumb: 'assets/images/filter_sweet.jpg'),
      FilterPreset(name: 'Fresh',     matrix: FilterMatrices.fresh,     assetThumb: 'assets/images/filter_fresh.jpg'),
      FilterPreset(name: 'Vibrant',   matrix: FilterMatrices.vibrant,   assetThumb: 'assets/images/filter_vibrant.jpg'),
      FilterPreset(name: 'Classic',   matrix: FilterMatrices.classic,   assetThumb: 'assets/images/filter_classic.jpg'),
    ],
    'Vibes': [
      FilterPreset(name: 'Retro',   matrix: FilterMatrices.retro,   assetThumb: 'assets/images/filter_retro.jpg'),
      FilterPreset(name: 'Vintage', matrix: FilterMatrices.vintage, assetThumb: 'assets/images/filter_vintage.jpg'),
      FilterPreset(name: 'Film',    matrix: FilterMatrices.film,    assetThumb: 'assets/images/filter_film.jpg'),
      FilterPreset(name: 'Dreamy',  matrix: FilterMatrices.dreamy,  assetThumb: 'assets/images/filter_dreamy.jpg'),
      FilterPreset(name: 'Moody',   matrix: FilterMatrices.moody,   assetThumb: 'assets/images/filter_moody.jpg'),
      FilterPreset(name: 'Urban',   matrix: FilterMatrices.urban,   assetThumb: 'assets/images/filter_urban.jpg'),
    ],
    'Style': [
      FilterPreset(name: 'Modern',    matrix: FilterMatrices.modern,    assetThumb: 'assets/images/filter_modern.jpg'),
      FilterPreset(name: 'Minimal',   matrix: FilterMatrices.minimal,   assetThumb: 'assets/images/filter_minimal.jpg'),
      FilterPreset(name: 'Bold',      matrix: FilterMatrices.bold,      assetThumb: 'assets/images/filter_bold.jpg'),
      FilterPreset(name: 'Elegant',   matrix: FilterMatrices.elegant,   assetThumb: 'assets/images/filter_elegant.jpg'),
      FilterPreset(name: 'Artistic',  matrix: FilterMatrices.artistic,  assetThumb: 'assets/images/filter_artistic.jpg'),
      FilterPreset(name: 'Cinematic', matrix: FilterMatrices.cinematic, assetThumb: 'assets/images/filter_cinematic.jpg'),
    ],
  };

  List<double> get _activeMatrix {
    if (_selected == null) return FilterMatrices.identity;
    return FilterMatrices.blend(_selected!.matrix, _intensity);
  }

  List<FilterPreset> get _currentFilters =>
      _allFilters[_categories[_catIndex]] ?? [];

  // ── Notify parent (live preview) ───────────────────────────────────────────
  void _notifyPreview() {
    widget.onPreviewChanged?.call(_activeMatrix);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 6,
        top: 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCategoryBar(),
          const SizedBox(height: 10),
          _buildFilterStrip(),
          const SizedBox(height: 10),
          _buildSliderRow(),   // ── intensity slider + Reset
          const SizedBox(height: 10),
          _buildBottomRow(),   // ── ✗  ✓
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Category top bar ────────────────────────────────────────────────────────

  Widget _buildCategoryBar() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 20),
        itemBuilder: (_, i) {
          final isSel = _catIndex == i;
          final isNo  = i == 0;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _catIndex = i;
                if (isNo) {
                  _selected = null;
                  _notifyPreview();
                }
              });
            },
            child: isNo
            // ── "None" — icon + label ──────────────────────────────────
                ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.do_not_disturb_alt_outlined,
                      color: isSel ? Colors.white : Colors.white54,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'None',
                      style: TextStyle(
                        color: isSel ? Colors.white : Colors.white54,
                        fontSize: isSel ? 15 : 14,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 2,
                  width: isSel ? 20 : 0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            )
            // ── Other categories ────────────────────────────────────────
                : Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _categories[i],
                  style: TextStyle(
                    color: isSel ? Colors.white : Colors.white54,
                    fontSize: isSel ? 15 : 14,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 2,
                  width: isSel ? 20 : 0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Horizontal filter strip ─────────────────────────────────────────────────

  Widget _buildFilterStrip() {
    if (_catIndex == 0) {
      // None selected state
      return SizedBox(
        height: 110,
        child: Center(
          child: GestureDetector(
            onTap: () {
              setState(() => _selected = null);
              _notifyPreview();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(Icons.do_not_disturb_alt_outlined,
                      color: Colors.white54, size: 32),
                ),
                const SizedBox(height: 5),
                const Text('No Filter',
                    style: TextStyle(color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }

    final filters = _currentFilters;

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: filters.length,
        itemBuilder: (_, i) {
          final f     = filters[i];
          final isSel = _selected?.name == f.name;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selected  = f;
                _intensity = 100.0;
              });
              _notifyPreview();
            },
            child: Container(
              width: 82,
              margin: const EdgeInsets.only(right: 10),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 82,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: isSel
                          ? Border.all(color: Colors.white, width: 2.5)
                          : Border.all(color: Colors.transparent, width: 2.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildThumb(f),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    f.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Thumbnail ───────────────────────────────────────────────────────────────

  Widget _buildThumb(FilterPreset f) {
    if (f.assetThumb != null) {
      return ColorFiltered(
        colorFilter: ColorFilter.matrix(f.matrix),
        child: Image.asset(
          f.assetThumb!,
          fit: BoxFit.cover,
          width: 82,
          height: 82,
          errorBuilder: (_, __, ___) => _buildImageThumb(f),
        ),
      );
    }
    return _buildImageThumb(f);
  }

  Widget _buildImageThumb(FilterPreset f) {
    if (!widget.isVideo) {
      return ColorFiltered(
        colorFilter: ColorFilter.matrix(f.matrix),
        child: Image.file(
          widget.mediaFile,
          fit: BoxFit.cover,
          width: 82,
          height: 82,
          cacheWidth: 150,
          errorBuilder: (_, __, ___) => _buildColorThumb(f),
        ),
      );
    }
    return _buildColorThumb(f);
  }

  Widget _buildColorThumb(FilterPreset f) {
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(f.matrix),
      child: Container(
        width: 82,
        height: 82,
        color: const Color(0xFF888888),
        child: const Icon(Icons.image_outlined, color: Colors.white30, size: 26),
      ),
    );
  }

  // ── Intensity slider row + Reset button ────────────────────────────────────

  Widget _buildSliderRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // Intensity label
          const Text(
            'Intensity',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(width: 8),

          // Slider
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Colors.white24,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                trackHeight: 3,
              ),
              child: Slider(
                value: _selected != null ? _intensity : 0,
                min: 0,
                max: 100,
                onChanged: _selected == null
                    ? null
                    : (v) {
                  setState(() => _intensity = v);
                  _notifyPreview();
                },
              ),
            ),
          ),

          // % label
          SizedBox(
            width: 36,
            child: Text(
              _selected != null ? '${_intensity.round()}%' : '--',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),

          // ── Reset button ──────────────────────────────────────────────────
          GestureDetector(
            onTap: _selected == null
                ? null
                : () {
              HapticFeedback.selectionClick();
              setState(() => _intensity = 100.0);
              _notifyPreview();
            },
            child: Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _selected != null
                    ? Colors.white.withOpacity(0.15)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Reset',
                style: TextStyle(
                  color: _selected != null ? Colors.white : Colors.white30,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom row: ✗  ✓ ───────────────────────────────────────────────────────

  Widget _buildBottomRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ✗ Cancel — original matrix restore
          GestureDetector(
            onTap: () {
              // Restore original (no filter) before closing
              widget.onPreviewChanged?.call(FilterMatrices.identity);
              Navigator.pop(context);
            },
            child: const Icon(Icons.close, color: Colors.white, size: 28),
          ),

          // ✓ Apply
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context, {
                'preset':    _selected,
                'matrix':    _activeMatrix,
                'intensity': _intensity,
              });
            },
            child: const Icon(Icons.check, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}