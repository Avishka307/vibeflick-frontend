import 'package:flutter/material.dart';

class EffectsActivity extends StatefulWidget {
  final Function(String)? onEffectSelected;

  const EffectsActivity({super.key, this.onEffectSelected});

  @override
  State<EffectsActivity> createState() => _EffectsActivityState();
}

class _EffectsActivityState extends State<EffectsActivity> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedCategoryIndex = 0;

  // Categories
  final List<String> categories = [
    "Trending",
    "Lankan",
    "Beauty",
    "Visual",
    "Backgnd",
    "Funny"
  ];

  // Effects data - category wise
  final Map<String, List<EffectItem>> effectsByCategory = {
    "Trending": [
      EffectItem(name: "Glow Up", icon: Icons.auto_awesome, color: Color(0xFFFF3B5C)),
      EffectItem(name: "Vintage", icon: Icons.camera_roll, color: Color(0xFFFFA500)),
      EffectItem(name: "Neon", icon: Icons.lightbulb, color: Color(0xFF00F5FF)),
      EffectItem(name: "Sparkle", icon: Icons.star, color: Color(0xFFFFD700)),
      EffectItem(name: "Rainbow", icon: Icons.color_lens, color: Color(0xFF9C27B0)),
      EffectItem(name: "3D Face", icon: Icons.face_retouching_natural, color: Color(0xFF4CAF50)),
      EffectItem(name: "Glitch", icon: Icons.flash_on, color: Color(0xFFE91E63)),
      EffectItem(name: "Dreamy", icon: Icons.cloud, color: Color(0xFF03A9F4)),
    ],
    "Lankan": [
      EffectItem(name: "Wes-Face", icon: Icons.theater_comedy, color: Color(0xFFFF6B35)),
      EffectItem(name: "Village-Vibe", icon: Icons.home, color: Color(0xFF8B4513)),
      EffectItem(name: "Sigiri-Art", icon: Icons.palette, color: Color(0xFFD32F2F)),
      EffectItem(name: "70s-Cinema", icon: Icons.movie, color: Color(0xFFFFB300)),
    ],
    "Beauty": [
      EffectItem(name: "Smooth", icon: Icons.face, color: Color(0xFFFF69B4)),
      EffectItem(name: "Makeup", icon: Icons.brush, color: Color(0xFFDC143C)),
      EffectItem(name: "Eye Bright", icon: Icons.remove_red_eye, color: Color(0xFF00CED1)),
      EffectItem(name: "Blush", icon: Icons.favorite, color: Color(0xFFFF1493)),
      EffectItem(name: "Lipstick", icon: Icons.favorite, color: Color(0xFFC71585)),
      EffectItem(name: "Glow Skin", icon: Icons.wb_sunny, color: Color(0xFFFFDAB9)),
      EffectItem(name: "Contour", icon: Icons.face_retouching_natural, color: Color(0xFFD2691E)),
      EffectItem(name: "Filter", icon: Icons.filter_vintage, color: Color(0xFFBA55D3)),
    ],
    "Visual": [
      EffectItem(name: "Blur BG", icon: Icons.blur_on, color: Color(0xFF6A5ACD)),
      EffectItem(name: "Bokeh", icon: Icons.camera, color: Color(0xFF20B2AA)),
      EffectItem(name: "Cinematic", icon: Icons.movie_filter, color: Color(0xFF2F4F4F)),
      EffectItem(name: "VHS", icon: Icons.videocam, color: Color(0xFF8B0000)),
      EffectItem(name: "Chromatic", icon: Icons.gradient, color: Color(0xFF4169E1)),
      EffectItem(name: "Prism", icon: Icons.lens, color: Color(0xFF9370DB)),
      EffectItem(name: "Mirror", icon: Icons.flip, color: Color(0xFF5F9EA0)),
      EffectItem(name: "Kaleidoscope", icon: Icons.apps, color: Color(0xFFFF4500)),
    ],
    "Backgnd": [
      EffectItem(name: "Beach", icon: Icons.beach_access, color: Color(0xFF00BFFF)),
      EffectItem(name: "City", icon: Icons.location_city, color: Color(0xFF696969)),
      EffectItem(name: "Space", icon: Icons.stars, color: Color(0xFF191970)),
      EffectItem(name: "Forest", icon: Icons.park, color: Color(0xFF228B22)),
      EffectItem(name: "Studio", icon: Icons.photo_camera_back, color: Color(0xFF000000)),
      EffectItem(name: "Gradient", icon: Icons.gradient, color: Color(0xFFFF1493)),
      EffectItem(name: "Sunset", icon: Icons.wb_twilight, color: Color(0xFFFF6347)),
      EffectItem(name: "Party", icon: Icons.celebration, color: Color(0xFFFF00FF)),
    ],
    "Funny": [
      EffectItem(name: "Big Head", icon: Icons.face, color: Color(0xFFFFD700)),
      EffectItem(name: "Cartoon", icon: Icons.emoji_emotions, color: Color(0xFF32CD32)),
      EffectItem(name: "Voice FX", icon: Icons.record_voice_over, color: Color(0xFFFF69B4)),
      EffectItem(name: "Animal", icon: Icons.pets, color: Color(0xFFFFA500)),
      EffectItem(name: "Old Age", icon: Icons.elderly, color: Color(0xFF808080)),
      EffectItem(name: "Baby Face", icon: Icons.child_care, color: Color(0xFFFFB6C1)),
      EffectItem(name: "Alien", icon: Icons.face_6, color: Color(0xFF00FF00)),
      EffectItem(name: "Zombie", icon: Icons.face_5, color: Color(0xFF556B2F)),
    ],
  };

  String? selectedEffect;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedCategoryIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _clearEffect() {
    setState(() {
      selectedEffect = null;
    });
    // Notify parent to clear effect
    widget.onEffectSelected?.call('none');
  }

  void _closeSheet() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.75,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Top Header
          _buildHeader(),

          // Category Tabs
          _buildCategoryTabs(),

          // Effects Grid
          Expanded(
            child: _buildEffectsGrid(),
          ),

          // Bottom Action Bar
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: const Color(0xFFFF3B5C),
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                categories[_selectedCategoryIndex],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: _closeSheet,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                color: Colors.white.withOpacity(0.9),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: const Color(0xFFFF3B5C),
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.5),
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        dividerColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tabs: categories.map((category) {
          return Tab(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(category),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEffectsGrid() {
    return TabBarView(
      controller: _tabController,
      children: categories.map((category) {
        final categoryEffects = effectsByCategory[category] ?? [];

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemCount: categoryEffects.length,
          itemBuilder: (context, index) {
            final effect = categoryEffects[index];
            final isSelected = selectedEffect == effect.name;

            return _buildEffectItem(effect, isSelected);
          },
        );
      }).toList(),
    );
  }

  Widget _buildEffectItem(EffectItem effect, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedEffect = isSelected ? null : effect.name;
        });

        // Notify parent about effect change for live preview
        if (!isSelected) {
          widget.onEffectSelected?.call(effect.name);
        } else {
          widget.onEffectSelected?.call('none');
        }
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isSelected
                  ? effect.color
                  : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? effect.color
                    : Colors.white.withOpacity(0.3),
                width: isSelected ? 3 : 2,
              ),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: effect.color.withOpacity(0.6),
                  blurRadius: 16,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: effect.color.withOpacity(0.3),
                  blurRadius: 24,
                  spreadRadius: 5,
                ),
              ]
                  : [],
            ),
            child: Icon(
              effect.icon,
              color: Colors.white,
              size: isSelected ? 32 : 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            effect.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? effect.color : Colors.white.withOpacity(0.9),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Current effect display
          Expanded(
            child: selectedEffect != null
                ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B5C).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFF3B5C),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: const Color(0xFFFF3B5C),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        selectedEffect!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
                : Text(
              'Select an effect',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ),

          // Clear button
          if (selectedEffect != null)
            GestureDetector(
              onTap: _clearEffect,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.clear,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Clear',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EffectItem {
  final String name;
  final IconData icon;
  final Color color;

  EffectItem({
    required this.name,
    required this.icon,
    required this.color,
  });
}