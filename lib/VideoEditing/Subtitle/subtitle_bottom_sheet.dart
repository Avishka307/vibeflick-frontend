import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:io';

class SubtitleBottomSheet extends StatefulWidget {
  final File mediaFile;
  final bool isVideo;

  const SubtitleBottomSheet({
    super.key,
    required this.mediaFile,
    required this.isVideo,
  });

  @override
  State<SubtitleBottomSheet> createState() => _SubtitleBottomSheetState();
}

class _SubtitleBottomSheetState extends State<SubtitleBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  final ScrollController _optionsScrollController = ScrollController();

  // Subtitle customization options
  String selectedFont = 'Roboto';
  Color textColor = Colors.white;
  Color backgroundColor = Colors.black;
  double fontSize = 24.0;
  String textAlign = 'center';
  String selectedStyle = 'Classic';
  String selectedPreset = 'Default';
  double backgroundOpacity = 0.7;
  bool hasOutline = true;
  bool hasShadow = true;
  String selectedAnimation = 'Fade In';

  // Timeline & Duration
  double videoDuration = 10.0; // Video duration in seconds (mock value)
  RangeValues timeRange = const RangeValues(0.0, 5.0);

  // Position & Transform
  Offset textPosition = const Offset(0, 0); // Center offset
  double textScale = 1.0;
  double textRotation = 0.0;

  // Active section for horizontal lists
  String activeSection = '';

  // Editing state
  bool isEditingOnPreview = false;

  final List<String> fonts = [
    'Roboto',
    'Arial',
    'Helvetica',
    'Times New Roman',
    'Georgia',
    'Courier',
    'Verdana',
    'Comic Sans',
  ];

  final List<Color> popularColors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.pink,
    const Color(0xFF2196F3),
  ];

  final List<Map<String, dynamic>> subtitleStyles = [
    {'name': 'Classic', 'icon': Icons.text_fields},
    {'name': 'Bold', 'icon': Icons.format_bold},
    {'name': 'Outline', 'icon': Icons.border_outer},
    {'name': 'Shadow', 'icon': Icons.blur_on},
    {'name': 'Glow', 'icon': Icons.auto_awesome},
    {'name': 'Neon', 'icon': Icons.lightbulb_outline},
  ];

  final List<Map<String, dynamic>> animations = [
    {'name': 'Fade In', 'icon': Icons.opacity},
    {'name': 'Slide Up', 'icon': Icons.arrow_upward},
    {'name': 'Bounce', 'icon': Icons.source},
    {'name': 'Zoom', 'icon': Icons.zoom_in},
    {'name': 'Type Writer', 'icon': Icons.keyboard},
    {'name': 'Wave', 'icon': Icons.waves},
  ];

  // Ready-made presets
  final List<Map<String, dynamic>> presets = [
    {
      'name': 'Default',
      'icon': Icons.settings,
      'textColor': Colors.white,
      'bgColor': Colors.black,
      'fontSize': 24.0,
      'style': 'Classic',
      'hasOutline': true,
      'hasShadow': true,
    },
    {
      'name': 'Bold Yellow',
      'icon': Icons.wb_sunny,
      'textColor': Colors.yellow,
      'bgColor': Colors.black,
      'fontSize': 28.0,
      'style': 'Bold',
      'hasOutline': true,
      'hasShadow': true,
    },
    {
      'name': 'Neon Glow',
      'icon': Icons.auto_awesome,
      'textColor': const Color(0xFF00FF88),
      'bgColor': Colors.transparent,
      'fontSize': 26.0,
      'style': 'Glow',
      'hasOutline': false,
      'hasShadow': false,
    },
    {
      'name': 'Movie Classic',
      'icon': Icons.movie,
      'textColor': Colors.white,
      'bgColor': Colors.black,
      'fontSize': 22.0,
      'style': 'Classic',
      'hasOutline': false,
      'hasShadow': true,
    },
    {
      'name': 'Red Alert',
      'icon': Icons.warning,
      'textColor': Colors.white,
      'bgColor': Colors.red.shade700,
      'fontSize': 26.0,
      'style': 'Bold',
      'hasOutline': true,
      'hasShadow': true,
    },
    {
      'name': 'Cool Blue',
      'icon': Icons.ac_unit,
      'textColor': Colors.white,
      'bgColor': const Color(0xFF1976D2),
      'fontSize': 24.0,
      'style': 'Shadow',
      'hasOutline': false,
      'hasShadow': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Focus on text input when sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    _optionsScrollController.dispose();
    super.dispose();
  }

  void _applyPreset(Map<String, dynamic> preset) {
    setState(() {
      selectedPreset = preset['name'];
      textColor = preset['textColor'];
      backgroundColor = preset['bgColor'];
      fontSize = preset['fontSize'];
      selectedStyle = preset['style'];
      hasOutline = preset['hasOutline'];
      hasShadow = preset['hasShadow'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildLargePreview(),
          ),
          _buildTimeline(),
          _buildQuickControls(),
          if (activeSection.isNotEmpty) _buildHorizontalList(),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Add Subtitle',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check, size: 28, color: Color(0xFF2196F3)),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Subtitle added successfully!'),
                  backgroundColor: Color(0xFF2196F3),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Large fullscreen-style preview with drag & transform support
  Widget _buildLargePreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Media preview background
            Center(
              child: Icon(
                widget.isVideo ? Icons.videocam : Icons.image,
                size: 80,
                color: Colors.white24,
              ),
            ),

            // Draggable & transformable subtitle
            Positioned.fill(
              child: GestureDetector(
                onDoubleTap: () {
                  setState(() {
                    isEditingOnPreview = true;
                  });
                  _textFocusNode.requestFocus();
                },
                child: Stack(
                  children: [
                    // Draggable text widget
                    Positioned(
                      left: MediaQuery.of(context).size.width / 2 + textPosition.dx - 100,
                      top: MediaQuery.of(context).size.height * 0.3 + textPosition.dy,
                      child: GestureDetector(
                        onScaleStart: (details) {
                          // Initialize scale
                        },
                        onScaleUpdate: (details) {
                          setState(() {
                            // Handle drag (when scale is 1.0, it's just a drag)
                            textPosition = Offset(
                              textPosition.dx + details.focalPointDelta.dx,
                              textPosition.dy + details.focalPointDelta.dy,
                            );

                            // Handle zoom (pinch)
                            if (details.scale != 1.0) {
                              textScale = (textScale * details.scale).clamp(0.5, 3.0);
                            }

                            // Handle rotation
                            if (details.rotation != 0.0) {
                              textRotation += details.rotation;
                            }
                          });
                        },
                        child: Transform.rotate(
                          angle: textRotation,
                          child: Transform.scale(
                            scale: textScale,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: backgroundColor.withOpacity(backgroundOpacity),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: hasShadow
                                    ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                                    : null,
                                border: hasOutline
                                    ? Border.all(color: Colors.white, width: 2)
                                    : null,
                              ),
                              child: Text(
                                _textController.text.isEmpty
                                    ? 'Double tap to edit'
                                    : _textController.text,
                                textAlign: textAlign == 'center'
                                    ? TextAlign.center
                                    : textAlign == 'left'
                                    ? TextAlign.left
                                    : TextAlign.right,
                                style: TextStyle(
                                  fontFamily: selectedFont,
                                  fontSize: fontSize,
                                  color: textColor,
                                  fontWeight: selectedStyle == 'Bold'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  shadows: selectedStyle == 'Glow'
                                      ? [
                                    Shadow(
                                      color: textColor.withOpacity(0.8),
                                      blurRadius: 20,
                                    ),
                                  ]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Instruction overlay
            if (_textController.text.isEmpty)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '🎯 Drag to move • 🤏 Pinch to zoom • ✏️ Double tap to edit',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Timeline with range slider
  Widget _buildTimeline() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 20, color: Color(0xFF2196F3)),
              const SizedBox(width: 8),
              const Text(
                'Duration',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                '${timeRange.start.toStringAsFixed(1)}s - ${timeRange.end.toStringAsFixed(1)}s',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Range Slider
          RangeSlider(
            values: timeRange,
            min: 0,
            max: videoDuration,
            divisions: 100,
            activeColor: const Color(0xFF2196F3),
            inactiveColor: Colors.grey.shade300,
            labels: RangeLabels(
              '${timeRange.start.toStringAsFixed(1)}s',
              '${timeRange.end.toStringAsFixed(1)}s',
            ),
            onChanged: (RangeValues values) {
              setState(() {
                timeRange = values;
              });
            },
          ),
        ],
      ),
    );
  }

  // Horizontal scrollable quick controls
  Widget _buildQuickControls() {
    return Container(
      height: 140,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: TextField(
              controller: _textController,
              focusNode: _textFocusNode,
              maxLines: 1,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Type subtitle here...',
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: const Icon(Icons.edit, color: Color(0xFF2196F3)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
                ),
              ),
            ),
          ),

          // Horizontal options
          Expanded(
            child: SingleChildScrollView(
              controller: _optionsScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildQuickOption(
                    icon: Icons.style,
                    label: 'Presets',
                    onTap: () {
                      setState(() {
                        activeSection = activeSection == 'presets' ? '' : 'presets';
                      });
                    },
                    isActive: activeSection == 'presets',
                  ),
                  _buildQuickOption(
                    icon: Icons.format_size,
                    label: 'Size',
                    onTap: () {
                      setState(() {
                        activeSection = activeSection == 'size' ? '' : 'size';
                      });
                    },
                    isActive: activeSection == 'size',
                  ),
                  _buildQuickOption(
                    icon: Icons.font_download,
                    label: 'Font',
                    onTap: () {
                      setState(() {
                        activeSection = activeSection == 'font' ? '' : 'font';
                      });
                    },
                    isActive: activeSection == 'font',
                  ),
                  _buildQuickOption(
                    icon: Icons.palette,
                    label: 'Color',
                    onTap: () {
                      setState(() {
                        activeSection = activeSection == 'color' ? '' : 'color';
                      });
                    },
                    isActive: activeSection == 'color',
                  ),
                  _buildQuickOption(
                    icon: Icons.format_paint,
                    label: 'Style',
                    onTap: () {
                      setState(() {
                        activeSection = activeSection == 'style' ? '' : 'style';
                      });
                    },
                    isActive: activeSection == 'style',
                  ),
                  _buildQuickOption(
                    icon: Icons.animation,
                    label: 'Animation',
                    onTap: () {
                      setState(() {
                        activeSection = activeSection == 'animation' ? '' : 'animation';
                      });
                    },
                    isActive: activeSection == 'animation',
                  ),
                  _buildQuickOption(
                    icon: Icons.format_align_center,
                    label: 'Align',
                    onTap: () {
                      setState(() {
                        activeSection = activeSection == 'align' ? '' : 'align';
                      });
                    },
                    isActive: activeSection == 'align',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 70,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2196F3) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? const Color(0xFF2196F3) : Colors.grey.shade300,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : const Color(0xFF2196F3),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Horizontal list for selected option
  Widget _buildHorizontalList() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getSectionTitle(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() {
                      activeSection = '';
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildSectionContent(),
          ),
        ],
      ),
    );
  }

  String _getSectionTitle() {
    switch (activeSection) {
      case 'presets':
        return 'Select Preset';
      case 'size':
        return 'Font Size: ${fontSize.round()}';
      case 'font':
        return 'Select Font';
      case 'color':
        return 'Select Color';
      case 'style':
        return 'Select Style';
      case 'animation':
        return 'Select Animation';
      case 'align':
        return 'Text Alignment';
      default:
        return '';
    }
  }

  Widget _buildSectionContent() {
    switch (activeSection) {
      case 'presets':
        return _buildPresetsList();
      case 'size':
        return _buildSizeSlider();
      case 'font':
        return _buildFontsList();
      case 'color':
        return _buildColorsList();
      case 'style':
        return _buildStylesList();
      case 'animation':
        return _buildAnimationsList();
      case 'align':
        return _buildAlignmentList();
      default:
        return const SizedBox();
    }
  }

  Widget _buildPresetsList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final preset = presets[index];
        final isSelected = selectedPreset == preset['name'];
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => _applyPreset(preset),
            child: Container(
              width: 100,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2196F3) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    preset['icon'],
                    color: isSelected ? Colors.white : Colors.black87,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    preset['name'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSizeSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Slider(
            value: fontSize,
            min: 12,
            max: 48,
            divisions: 36,
            activeColor: const Color(0xFF2196F3),
            onChanged: (value) {
              setState(() {
                fontSize = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFontsList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: fonts.length,
      itemBuilder: (context, index) {
        final font = fonts[index];
        final isSelected = selectedFont == font;
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedFont = font;
              });
            },
            child: Container(
              width: 100,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2196F3) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  font,
                  style: TextStyle(
                    fontFamily: font,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorsList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: popularColors.length,
      itemBuilder: (context, index) {
        final color = popularColors[index];
        final isSelected = textColor == color;
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {
              setState(() {
                textColor = color;
              });
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade300,
                  width: isSelected ? 4 : 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                Icons.check,
                color: Colors.white,
                size: 30,
              )
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStylesList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: subtitleStyles.length,
      itemBuilder: (context, index) {
        final style = subtitleStyles[index];
        final isSelected = selectedStyle == style['name'];
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedStyle = style['name'];
              });
            },
            child: Container(
              width: 80,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2196F3) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    style['icon'],
                    color: isSelected ? Colors.white : Colors.black87,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    style['name'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimationsList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: animations.length,
      itemBuilder: (context, index) {
        final animation = animations[index];
        final isSelected = selectedAnimation == animation['name'];
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedAnimation = animation['name'];
              });
            },
            child: Container(
              width: 90,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2196F3) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    animation['icon'],
                    color: isSelected ? Colors.white : Colors.black87,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    animation['name'],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlignmentList() {
    final alignments = [
      {'name': 'Left', 'icon': Icons.format_align_left, 'value': 'left'},
      {'name': 'Center', 'icon': Icons.format_align_center, 'value': 'center'},
      {'name': 'Right', 'icon': Icons.format_align_right, 'value': 'right'},
    ];

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: alignments.length,
      itemBuilder: (context, index) {
        final alignment = alignments[index];
        final isSelected = textAlign == alignment['value'];
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {
              setState(() {
                textAlign = alignment['value'] as String;
              });
            },
            child: Container(
              width: 80,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2196F3) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    alignment['icon'] as IconData,
                    color: isSelected ? Colors.white : Colors.black87,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    alignment['name'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _textController.clear();
                  selectedFont = 'Roboto';
                  textColor = Colors.white;
                  backgroundColor = Colors.black;
                  fontSize = 24.0;
                  textAlign = 'center';
                  selectedStyle = 'Classic';
                  selectedPreset = 'Default';
                  backgroundOpacity = 0.7;
                  hasOutline = true;
                  hasShadow = true;
                  selectedAnimation = 'Fade In';
                  textPosition = const Offset(0, 0);
                  textScale = 1.0;
                  textRotation = 0.0;
                  timeRange = const RangeValues(0.0, 5.0);
                  activeSection = '';
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFF2196F3), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Reset',
                style: TextStyle(
                  color: Color(0xFF2196F3),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Subtitle added successfully!'),
                    backgroundColor: Color(0xFF2196F3),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Add Subtitle',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
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