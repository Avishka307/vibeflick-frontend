import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';  // මේ line එක add කරන්න
import 'package:video_player/video_player.dart';
// 🎵 AUDIO INTEGRATION

import '../Notification/audio_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
class TextPostScreen extends StatefulWidget {
  const TextPostScreen({super.key});

  @override
  State<TextPostScreen> createState() => _TextPostScreenState();
}

class _TextPostScreenState extends State<TextPostScreen>
    with TickerProviderStateMixin {
  // Text Content
  final TextEditingController _textController = TextEditingController();
  String currentText = '';
  // 🆕 Editing Mode
  bool isEditingText = false;
  int? editingTextIndex;
  final int maxTextLength = 700; // WhatsApp status වගේ

  // Background
  int selectedBackgroundIndex = 0;
  late AnimationController _gradientController;
  late Animation<double> _gradientAnimation;
  File? _backgroundImage; // 🆕 Gallery background

  // Layout & Style
  TextAlign currentAlignment = TextAlign.center;
  String selectedLayout = 'center';
  double fontSize = 32.0;
  String selectedFont = 'Poppins';
  Color textColor = Colors.white;
  bool isBold = false;
  bool isItalic = false;
  Function(int, String)? _updateVideoProgress;
  // 🎨 Text Background Highlight
  bool hasTextBackground = false;
  Color textBackgroundColor = Colors.black;

  // 🆕 Multiple draggable text elements
  List<DraggableText> textElements = [];

  // 🎨 Font Picker List
  final List<String> availableFonts = [
    'Poppins',
    'Montserrat',
    'Roboto',
    'Pacifico',
    'Dancing Script',
    'Courier',
  ];

  // 🎨 Color Picker Palette with Effects
  final List<Map<String, dynamic>> colorOptions = [
    {'color': Colors.white, 'name': 'White', 'effect': 'none'},
    {'color': Colors.black, 'name': 'Black', 'effect': 'none'},
    {'color': const Color(0xFFFF3B5C), 'name': 'Pink', 'effect': 'glow'},
    {'color': const Color(0xFF667EEA), 'name': 'Purple', 'effect': 'glow'},
    {'color': const Color(0xFF0093E9), 'name': 'Blue', 'effect': 'glow'},
    {'color': const Color(0xFF00F260), 'name': 'Green', 'effect': 'neon'},
    {'color': const Color(0xFFFFD700), 'name': 'Gold', 'effect': 'shimmer'},
    {'color': const Color(0xFFFF6B9D), 'name': 'Rose', 'effect': 'glow'},
  ];

  // Emojis & Stickers
  List<DraggableEmoji> emojis = [];
  List<DraggableSticker> stickers = []; // 🆕 Stickers

  // 🗑️ Delete Zone
  bool showDeleteZone = false;
  bool isOverDeleteZone = false;

  // 🎵 Music Integration
  AudioTrackEnhanced? selectedMusic;
  final AudioPlayer _musicPlayer = AudioPlayer();
  bool isMusicPlaying = false;

  // 🆕 Poll/Question
  PollQuestion? activePoll;

  // Animation
  late AnimationController _textAnimController;

  // Canvas Key for Screenshot
  final GlobalKey _canvasKey = GlobalKey();

  // Bottom toolbar visibility
  bool showBottomTools = true;

  // 🚀 Performance
  bool useSimplifiedGraphics = true;

  // 🆕 Track changes & Undo/Redo
  bool hasUnsavedChanges = false;
  bool _isCaptureMode = false;  // ✅ NEW
  List<EditorState> undoStack = [];
  List<EditorState> redoStack = [];


  @override
  void initState() {
    super.initState();
    _checkDevicePerformance();

    _gradientController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);

    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gradientController, curve: Curves.easeInOut),
    );

    _textAnimController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _textController.addListener(() {
      setState(() {
        currentText = _textController.text;
        hasUnsavedChanges = true;

        // ✅ Auto Font Size Based on Character Count
        final length = currentText.length;
        if (length == 0) {
          fontSize = 32.0; // Default
        } else if (length <= 20) {
          fontSize = 48.0; // 🔥 කෙටි text - ඉතා ලොකු
        } else if (length <= 50) {
          fontSize = 40.0; // මධ්‍යම text - ලොකු
        } else if (length <= 100) {
          fontSize = 32.0; // දිග text - සාමාන්‍ය
        } else if (length <= 200) {
          fontSize = 28.0; // වැඩි දිග text - පොඩි
        } else if (length <= 350) {
          fontSize = 24.0; // ඉතා දිග text - ඊටත් පොඩි
        } else {
          fontSize = 20.0; // 🔥 Maximum text - smallest size
        }

        // ✅ Editing mode නම් existing text එකේ size එකත් update කරනවා
        if (isEditingText && editingTextIndex != null && textElements.isNotEmpty) {
          textElements[editingTextIndex!].fontSize = fontSize;
        }
      });
    });

    // Save initial state
    _saveState();
  }

  void _checkDevicePerformance() {
    setState(() {
      useSimplifiedGraphics = false;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _gradientController.dispose();
    _textAnimController.dispose();
    _musicPlayer.dispose();

    super.dispose();
  }

  // 🆕 Undo/Redo Logic
  void _saveState() {
    final state = EditorState(
      textElements: List.from(textElements),
      emojis: List.from(emojis),
      stickers: List.from(stickers),
      activePoll: activePoll,
      backgroundIndex: selectedBackgroundIndex,
      backgroundImage: _backgroundImage,
    );
    undoStack.add(state);
    redoStack.clear();
    if (undoStack.length > 20) undoStack.removeAt(0);
  }

  void _undo() {
    if (undoStack.length <= 1) return;

    HapticFeedback.lightImpact();
    final currentState = undoStack.removeLast();
    redoStack.add(currentState);

    final previousState = undoStack.last;
    setState(() {
      textElements = List.from(previousState.textElements);
      emojis = List.from(previousState.emojis);
      stickers = List.from(previousState.stickers);
      activePoll = previousState.activePoll;
      selectedBackgroundIndex = previousState.backgroundIndex;
      _backgroundImage = previousState.backgroundImage;
    });
  }

  void _redo() {
    if (redoStack.isEmpty) return;

    HapticFeedback.lightImpact();
    final state = redoStack.removeLast();
    undoStack.add(state);

    setState(() {
      textElements = List.from(state.textElements);
      emojis = List.from(state.emojis);
      stickers = List.from(state.stickers);
      activePoll = state.activePoll;
      selectedBackgroundIndex = state.backgroundIndex;
      _backgroundImage = state.backgroundImage;
    });
  }

  // Gradient Background Presets
  List<List<Color>> get backgroundGradients => [
    [const Color(0xFFFF6B9D), const Color(0xFFC06C84)],
    [const Color(0xFF667EEA), const Color(0xFF764BA2)],
    [const Color(0xFF4158D0), const Color(0xFFC850C0)],
    [const Color(0xFFF093FB), const Color(0xFFF5576C)],
    [const Color(0xFF0093E9), const Color(0xFF80D0C7)],
    [const Color(0xFF21D4FD), const Color(0xFFB721FF)],
    [const Color(0xFFFF9A56), const Color(0xFFFF6A88)],
    [const Color(0xFF00F260), const Color(0xFF0575E6)],
  ];

  void _changeBackground() {
    HapticFeedback.lightImpact();
    setState(() {
      selectedBackgroundIndex = (selectedBackgroundIndex + 1) % backgroundGradients.length;
      hasUnsavedChanges = true;
    });
    _saveState();
  }

  // 🆕 Gallery Background Picker
  Future<void> _pickBackgroundImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _backgroundImage = File(image.path);
        hasUnsavedChanges = true;
      });
      _saveState();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Background image added!'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _removeBackgroundImage() {
    HapticFeedback.mediumImpact();
    setState(() {
      _backgroundImage = null;
      hasUnsavedChanges = true;
    });
    _saveState();
  }
  void _changeLayout(String layout) {
    setState(() {
      selectedLayout = layout;
      hasUnsavedChanges = true;

      // Screen dimensions
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;

      final safeTop = 120.0;
      final safeBottom = screenHeight - 180.0;
      final safeCenterY = safeTop + (safeBottom - safeTop) / 2;

      if (layout == 'center') {
        currentAlignment = TextAlign.center;
        // ✅ Canvas එකේ මැදට position එක වෙනස් කරනවා
        if (textElements.isNotEmpty) {
          textElements.last.alignment = currentAlignment;
          textElements.last.position = Offset(screenWidth / 2, safeCenterY);
        }
      } else if (layout == 'left') {
        currentAlignment = TextAlign.left;
        // ✅ Canvas එකේ වම් පස position එක වෙනස් කරනවා
        if (textElements.isNotEmpty) {
          textElements.last.alignment = currentAlignment;
          textElements.last.position = Offset(60.0, safeCenterY);
        }
      } else if (layout == 'right') {
        currentAlignment = TextAlign.right;
        // ✅ Canvas එකේ දකුණු පස position එක වෙනස් කරනවා
        if (textElements.isNotEmpty) {
          textElements.last.alignment = currentAlignment;
          textElements.last.position = Offset(screenWidth - 60.0, safeCenterY);
        }
      } else if (layout == 'quote') {
        currentAlignment = TextAlign.left;
        // ✅ Quote style - වමට ටිකක් indent එකක් දෙනවා
        if (textElements.isNotEmpty) {
          textElements.last.alignment = currentAlignment;
          textElements.last.position = Offset(80.0, safeCenterY);
        }
      }
    });
  }
  void _addTextElement() {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please type some text first!'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final safeTop = 120.0;
    final safeBottom = screenHeight - 180.0;
    final safeLeft = 40.0;
    final safeRight = screenWidth - 80.0;

    final safeCenterY = safeTop + (safeBottom - safeTop) / 2;
    final safeCenterX = safeLeft + (safeRight - safeLeft) / 2;

    setState(() {
      textElements.add(DraggableText(
        text: _textController.text,
        position: Offset(safeCenterX, safeCenterY),
        fontSize: fontSize,
        fontFamily: selectedFont,
        color: textColor,
        isBold: isBold,
        isItalic: isItalic,
        hasBackground: hasTextBackground,
        backgroundColor: textBackgroundColor,
        alignment: currentAlignment,
      ));
      hasUnsavedChanges = true;
      currentText = '';
    });

    _saveState();


  }

  void _addEmoji(String emoji) {
    HapticFeedback.mediumImpact();

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final safeTop = 120.0;
    final safeBottom = screenHeight - 180.0;
    final safeLeft = 40.0;
    final safeRight = screenWidth - 80.0;

    final safeCenterY = safeTop + (safeBottom - safeTop) / 2;
    final safeCenterX = safeLeft + (safeRight - safeLeft) / 2;

    setState(() {
      emojis.add(DraggableEmoji(
        emoji: emoji,
        position: Offset(safeCenterX, safeCenterY),
      ));
      hasUnsavedChanges = true;
    });
    _saveState();
  }

  // 🆕 Add Sticker
  void _addSticker(String assetPath) {
    HapticFeedback.mediumImpact();

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final safeTop = 120.0;
    final safeBottom = screenHeight - 180.0;
    final safeLeft = 40.0;
    final safeRight = screenWidth - 80.0;

    final safeCenterY = safeTop + (safeBottom - safeTop) / 2;
    final safeCenterX = safeLeft + (safeRight - safeLeft) / 2;

    setState(() {
      stickers.add(DraggableSticker(
        assetPath: assetPath,
        position: Offset(safeCenterX, safeCenterY),
      ));
      hasUnsavedChanges = true;
    });
    _saveState();
  }

  Future<bool> _onWillPop() async {
    if (!hasUnsavedChanges && textElements.isEmpty && emojis.isEmpty &&
        stickers.isEmpty && selectedMusic == null && activePoll == null) {
      return true;
    }

    return await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFF3B5C),
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Save as Draft?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You have unsaved changes. What would you like to do?',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Save as Draft Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Save draft logic
                    Navigator.pop(context, false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(' Saved as draft!'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_outlined, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Save as Draft',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Continue Editing Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue Editing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Discard Button
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Discard',
                  style: TextStyle(
                    color: Color(0xFFFF3B5C),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ) ?? false;
  }

  Future<void> _goToFinalPostPage() async {
    if (textElements.isEmpty &&
        emojis.isEmpty &&
        stickers.isEmpty &&
        activePoll == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please add some content first!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      HapticFeedback.mediumImpact();

      final bool hasAnimations = stickers.isNotEmpty;
      final bool hasMusic = selectedMusic != null;

      // ── Stickers / Music ඇත්නම් → Video option offer ────
      if (hasAnimations || hasMusic) {
        final bool? shouldCreateVideo = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.video_library, color: Color(0xFFFF3B5C),
                    size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    hasMusic && hasAnimations
                        ? '🎬 Animation + Sound'
                        : hasMusic
                        ? '🎵 Post with Sound'
                        : '🎬 Animated Post',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Text(
              hasMusic && hasAnimations
                  ? 'Lottie stickers and music detected!\n\n'
                  '🎬 Video: Full animation with sound (MP4)\n'
                  '📷 Image: Static preview only'
                  : hasMusic
                  ? 'Music track detected!\n\n'
                  '🎬 Video: Post with background sound (MP4)\n'
                  '📷 Image: Silent static preview'
                  : 'Animated stickers detected!\n\n'
                  '🎬 Video: Animated post (MP4)\n'
                  '📷 Image: Static preview only',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('📷 Image Only',
                    style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981)),
                child: const Text('🎬 Create Video'),
              ),
            ],
          ),
        );

        if (shouldCreateVideo == true) {
          final String? videoPath = await _generateMP4Video();
          if (videoPath != null && mounted) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FinalPostPage(
                  imagePath: videoPath,
                  selectedMusic: selectedMusic,
                  hasPoll: activePoll != null,
                  isAnimated: true,
                ),
              ),
            );
            if (result == true && mounted) Navigator.pop(context, true);
            return;
          }
        }
      }

      // ── Default: Static PNG ───────────────────────────────
      setState(() {
        showBottomTools = false;
        _isCaptureMode = true;
      });
      await Future.delayed(const Duration(milliseconds: 150));

      final RenderRepaintBoundary boundary =
      _canvasKey.currentContext!.findRenderObject()
      as RenderRepaintBoundary;
      final ui.Image uiImage = await boundary.toImage(pixelRatio: 3.0);

      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = '${directory.path}/text_post_$timestamp.png';

      final byteData =
      await uiImage.toByteData(format: ui.ImageByteFormat.png);
      await File(imagePath).writeAsBytes(byteData!.buffer.asUint8List());

      setState(() {
        showBottomTools = true;
        _isCaptureMode = false;
      });
      HapticFeedback.heavyImpact();;

      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FinalPostPage(
              imagePath: imagePath,
              selectedMusic: selectedMusic,
              hasPoll: activePoll != null,
              isAnimated: false,
            ),
          ),
        );
        if (result == true && mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        showBottomTools = true;
        _isCaptureMode = false;
      });
      HapticFeedback.vibrate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: GestureDetector(
          onTap: () {
            // Hide keyboard and toggle toolbar
            FocusScope.of(context).unfocus();
            setState(() {
              showBottomTools = !showBottomTools;
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ✅ RepaintBoundary = background + canvas ONLY
              RepaintBoundary(
                key: _canvasKey,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background (Gradient or Image)
                    if (_backgroundImage != null)
                      Positioned.fill(
                        child: Image.file(
                          _backgroundImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      AnimatedBuilder(
                        animation: _gradientAnimation,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: backgroundGradients[selectedBackgroundIndex],
                                stops: [
                                  _gradientAnimation.value * 0.3,
                                  0.7 + (_gradientAnimation.value * 0.3),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    // Mesh Gradient Effect
                    if (!useSimplifiedGraphics && _backgroundImage == null)
                      Positioned.fill(
                        child: ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                          child: CustomPaint(
                            painter: MeshGradientPainter(
                              animation: _gradientAnimation,
                              colors: backgroundGradients[selectedBackgroundIndex],
                            ),
                          ),
                        ),
                      ),

                    // Draggable elements
                    ...textElements.map((e) => _buildDraggableText(e)),
                    ...emojis.map((e) => _buildDraggableEmoji(e)),
                    ...stickers.map((s) => _buildDraggableSticker(s)),
                    if (activePoll != null) _buildPoll(),
                    if (showDeleteZone) _buildDeleteZone(),
                  ],
                ),
              ),

              // ✅ UI overlay — RepaintBoundary OUTSIDE
              // Capture mode නම් hide → clean screenshot
              if (!_isCaptureMode)
                SafeArea(
                  child: Column(
                    children: [
                      _buildTopBar(),
                      if (selectedMusic != null) _buildMusicIndicator(),
                      const Spacer(),
                      if (showBottomTools) _buildBottomToolbar(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop) Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 24),
            ),
          ),

          // Undo/Redo Buttons
          Row(
            children: [
              GestureDetector(
                onTap: undoStack.length > 1 ? _undo : null,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.undo,
                    color: undoStack.length > 1 ? Colors.white : Colors.white38,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: redoStack.isNotEmpty ? _redo : null,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.redo,
                    color: redoStack.isNotEmpty ? Colors.white : Colors.white38,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),

          const Text(
            'Create Post',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          GestureDetector(
            onTap: _goToFinalPostPage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Text(
                    'Next',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B5C).withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_note, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedMusic!.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    selectedMusic!.artist,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  selectedMusic = null;
                  isMusicPlaying = false;
                });
                _musicPlayer.stop();
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableText(DraggableText textElement) {
    final index = textElements.indexOf(textElement);

    return Positioned(
      left: textElement.position.dx,
      top: textElement.position.dy,
      child: GestureDetector(
        // ✅ Single tap - Edit mode
        onTap: () {
          HapticFeedback.lightImpact();
          _editTextElement(index);
        },

        onScaleStart: (_) {
          HapticFeedback.lightImpact();
          setState(() => showDeleteZone = true);
        },
        onScaleUpdate: (details) {
          setState(() {
            textElement.scale = (textElement.scale * details.scale).clamp(0.3, 5.0);
            textElement.rotation += details.rotation;

            final screenHeight = MediaQuery.of(context).size.height;
            final screenWidth = MediaQuery.of(context).size.width;

            double newX = (textElement.position.dx + details.focalPointDelta.dx).clamp(40.0, screenWidth - 80.0);
            double newY = (textElement.position.dy + details.focalPointDelta.dy).clamp(120.0, screenHeight - 180.0);

            textElement.position = Offset(newX, newY);
            isOverDeleteZone = newY > screenHeight - 200;
          });
        },
        onScaleEnd: (_) {
          if (isOverDeleteZone) {
            HapticFeedback.heavyImpact();
            setState(() {
              textElements.remove(textElement);
              showDeleteZone = false;
              isOverDeleteZone = false;
            });
            _saveState();
          } else {
            HapticFeedback.lightImpact();
            setState(() {
              showDeleteZone = false;
              isOverDeleteZone = false;
            });
          }
        },
        child: Transform.rotate(
          angle: textElement.rotation,
          child: Transform.scale(
            scale: textElement.scale,
            child: Container(
              padding: textElement.hasBackground
                  ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                  : EdgeInsets.zero,
              decoration: textElement.hasBackground
                  ? BoxDecoration(
                color: textElement.backgroundColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              )
                  : null,
              // ✅ Calculate max width based on screen
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85, // 85% of screen width
                ),
                child: Text(
                  textElement.text,
                  style: TextStyle(
                    fontSize: textElement.fontSize,
                    fontFamily: textElement.fontFamily,
                    color: textElement.color,
                    fontWeight: textElement.isBold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: textElement.isItalic ? FontStyle.italic : FontStyle.normal,
                    height: 1.45, // ✅ Line height (nearby_post_card වගේම)
                    shadows: textElement.hasBackground ? [] : [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  textAlign: textElement.alignment,
                  softWrap: true, // ✅ Enable text wrapping
                  overflow: TextOverflow.visible, // ✅ Allow text to wrap to new lines
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🆕 Edit existing text element
  void _editTextElement(int index) {
    if (index < 0 || index >= textElements.length) return;

    final textElement = textElements[index];

    setState(() {
      isEditingText = true;
      editingTextIndex = index;
      _textController.text = textElement.text;
      currentText = textElement.text;
      fontSize = textElement.fontSize;
      selectedFont = textElement.fontFamily;
      textColor = textElement.color;
      isBold = textElement.isBold;
      isItalic = textElement.isItalic;
      hasTextBackground = textElement.hasBackground;
      textBackgroundColor = textElement.backgroundColor;
      currentAlignment = textElement.alignment;
    });

    _showTextInput();
  }
  Widget _buildDraggableEmoji(DraggableEmoji emoji) {
    return Positioned(
      left: emoji.position.dx,
      top: emoji.position.dy,
      child: GestureDetector(
        onScaleStart: (_) {
          HapticFeedback.lightImpact();
          setState(() => showDeleteZone = true);
        },
        onScaleUpdate: (details) {
          setState(() {
            emoji.scale = (emoji.scale * details.scale).clamp(0.5, 3.0);
            emoji.rotation += details.rotation;

            final screenHeight = MediaQuery.of(context).size.height;
            final screenWidth = MediaQuery.of(context).size.width;

            double newX = (emoji.position.dx + details.focalPointDelta.dx).clamp(40.0, screenWidth - 80.0);
            double newY = (emoji.position.dy + details.focalPointDelta.dy).clamp(120.0, screenHeight - 180.0);

            emoji.position = Offset(newX, newY);
            isOverDeleteZone = newY > screenHeight - 200;
          });
        },
        onScaleEnd: (_) {
          if (isOverDeleteZone) {
            HapticFeedback.heavyImpact();
            setState(() {
              emojis.remove(emoji);
              showDeleteZone = false;
              isOverDeleteZone = false;
            });
            _saveState();
          } else {
            HapticFeedback.lightImpact();
            setState(() {
              showDeleteZone = false;
              isOverDeleteZone = false;
            });
          }
        },
        child: Transform.rotate(
          angle: emoji.rotation,
          child: Transform.scale(
            scale: emoji.scale,
            child: Text(
              emoji.emoji,
              style: const TextStyle(fontSize: 48),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildDraggableSticker(DraggableSticker sticker) {
    return Positioned(
      left: sticker.position.dx,
      top: sticker.position.dy,
      child: GestureDetector(
        onScaleStart: (_) {
          HapticFeedback.lightImpact();
          setState(() => showDeleteZone = true);
        },
        onScaleUpdate: (details) {
          setState(() {
            sticker.scale = (sticker.scale * details.scale).clamp(0.5, 3.0);
            sticker.rotation += details.rotation;

            final screenHeight = MediaQuery.of(context).size.height;
            final screenWidth = MediaQuery.of(context).size.width;

            double newX = (sticker.position.dx + details.focalPointDelta.dx).clamp(40.0, screenWidth - 80.0);
            double newY = (sticker.position.dy + details.focalPointDelta.dy).clamp(120.0, screenHeight - 180.0);

            sticker.position = Offset(newX, newY);
            isOverDeleteZone = newY > screenHeight - 200;
          });
        },
        onScaleEnd: (_) {
          if (isOverDeleteZone) {
            HapticFeedback.heavyImpact();
            setState(() {
              stickers.remove(sticker);
              showDeleteZone = false;
              isOverDeleteZone = false;
            });
            _saveState();
          } else {
            HapticFeedback.lightImpact();
            setState(() {
              showDeleteZone = false;
              isOverDeleteZone = false;
            });
          }
        },
        child: Transform.rotate(
          angle: sticker.rotation,
          child: Transform.scale(
            scale: sticker.scale,
            child: Lottie.asset(
              sticker.assetPath,
              width: 100,
              height: 100,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 80,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoll() {
    if (activePoll == null) return const SizedBox.shrink();

    return Positioned(
      left: 20,
      right: 20,
      bottom: 200,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    activePoll!.question,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => activePoll = null);
                    _saveState();
                  },
                  child: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // දැන් options 4ක් පෙන්වනවා
            ...activePoll!.options.asMap().entries.map((entry) {
              int idx = entry.key;
              String option = entry.value;
              bool isCorrect = activePoll!.correctAnswerIndex == idx;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFFF3B5C),
                    width: isCorrect ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: isCorrect ? const Color(0xFF10B981).withOpacity(0.1) : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    if (isCorrect)
                      const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteZone() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              (isOverDeleteZone ? Colors.red : Colors.orange).withOpacity(0.8),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline,
              color: Colors.white,
              size: isOverDeleteZone ? 48 : 40,
            ),
            const SizedBox(height: 8),
            Text(
              isOverDeleteZone ? 'Release to Delete' : 'Drag Here to Delete',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildToolButton(Icons.text_fields, 'Type', _showTextInput),
                const SizedBox(width: 12),
                _buildToolButton(Icons.font_download, 'Font', _showFontPicker),
                const SizedBox(width: 12),
                _buildToolButton(Icons.palette, 'Color', _showColorPicker),
                const SizedBox(width: 12),
                _buildToolButton(Icons.format_size, 'Size', _showFontSizePicker),
                const SizedBox(width: 12),
                _buildToolButton(Icons.format_align_center, 'Layout', _showLayoutOptions),
                const SizedBox(width: 12),
                _buildToolButton(Icons.format_bold, 'Style', _showStyleOptions),
                const SizedBox(width: 12),
                _buildToolButton(Icons.emoji_emotions, 'Emoji', _showEmojiAndStickerPicker),
                const SizedBox(width: 12),
                _buildToolButton(Icons.image, 'BG', _showBackgroundOptions),
                const SizedBox(width: 12),
                _buildToolButton(Icons.poll, 'Poll', _showPollCreator),
                const SizedBox(width: 12),
                _buildToolButton(Icons.music_note, 'Music', _showMusicPicker),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
// 🎬 COMPLETE SOLUTION - TRUE ANIMATED GIF + MP4 VIDEO WITH SOUND
// ✅ මේ සම්පූර්ණ method එක copy කරලා ඔබේ _generateAnimatedGIF method එක replace කරන්න

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// METHOD 3 OF 3:  _generateAnimatedGIF()
// Sound නැත්නම් GIF, ඇත්නම් _generateMP4Video() ට redirect
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<String?> _generateAnimatedGIF() async {
    // ── Sound ඇත්නම් → Video ─────────────────────────
    if (selectedMusic != null) return _generateMP4Video();

    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    if (!mounted) return null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF3B5C)),
                ),
                SizedBox(height: 16),
                Text(
                  '🎨 Creating GIF...',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  'Capturing animation frames',
                  style:
                  TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      setState(() => showBottomTools = false);
      await Future.delayed(const Duration(milliseconds: 100));

      const int totalFrames = 30;
      const int frameDelay = 100;
      final List<img.Image> frames = [];

      for (int i = 0; i < totalFrames; i++) {
        await Future.delayed(const Duration(milliseconds: frameDelay));
        try {
          final RenderRepaintBoundary boundary =
          _canvasKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
          final ui.Image uiImg =
          await boundary.toImage(pixelRatio: 2.0);
          final bd = await uiImg
              .toByteData(format: ui.ImageByteFormat.png);
          final frame =
          img.decodeImage(bd!.buffer.asUint8List());
          if (frame != null) frames.add(frame);
        } catch (_) {}
      }

      if (frames.isEmpty) throw Exception('No frames captured');

      final gifEncoder = img.GifEncoder();
      for (final frame in frames) {
        gifEncoder.addFrame(frame, duration: frameDelay);
      }
      final gifData = gifEncoder.finish();
      if (gifData == null || gifData.isEmpty) {
        throw Exception('GIF encode failed');
      }

      final gifPath =
          '${directory.path}/animated_$timestamp.gif';
      await File(gifPath).writeAsBytes(gifData);

      setState(() => showBottomTools = true);
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ GIF created! (${frames.length} frames)'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        return gifPath;
      }
      return null;

    } catch (e) {
      setState(() => showBottomTools = true);
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('❌ GIF error: $e'),
              backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

// 🎵 Generate MP4 Video with Sound
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// METHOD 2 OF 3:  _generateMP4Video()
// ffmpeg_kit_flutter_new  →  frames + audio  →  MP4
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<String?> _generateMP4Video() async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final framesDir =
    Directory('${directory.path}/frames_$timestamp');
    await framesDir.create(recursive: true);

    // ── Progress Dialog ─────────────────────────────────
    int _pct = 0;
    String _label = 'Preparing...';

    if (!mounted) return null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          _updateVideoProgress = (int p, String l) {
            if (ctx.mounted) setDlg(() { _pct = p; _label = l; });
          };
          return WillPopScope(
            onWillPop: () async => false,       // ← back button block
            child: Center(
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🎬 Top gradient header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF3B5C), Color(0xFFFF6B9D)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.movie_creation, color: Colors.white, size: 36),
                          SizedBox(height: 8),
                          Text(
                            '🎬 Creating Your Video',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Progress percentage (big)
                    Text(
                      '$_pct%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _pct / 100,
                        minHeight: 12,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _pct < 50
                              ? const Color(0xFFFF3B5C)
                              : _pct < 90
                              ? const Color(0xFFFF9A56)
                              : const Color(0xFF10B981),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Step label
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Tip
                    Text(
                      'Please keep the app open',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 10,
                      ),




                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    try {
      setState(() { showBottomTools = false; _isCaptureMode = true; });
      _updateVideoProgress?.call(5, 'Capturing animation frames...');

      // ── 1. Capture 60 frames @ 10fps ──────────────────
      const int totalFrames = 30;
      const int frameDelayMs = 50;
      int capturedCount = 0;

      for (int i = 0; i < totalFrames; i++) {
        await Future.delayed(const Duration(milliseconds: frameDelayMs));
        try {
          final RenderRepaintBoundary boundary =
          _canvasKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
          final ui.Image uiImg =
          await boundary.toImage(pixelRatio: 2.0);
          final bd = await uiImg
              .toByteData(format: ui.ImageByteFormat.png);
          final framePath =
              '${framesDir.path}/frame_${i.toString().padLeft(4, '0')}.png';
          await File(framePath)
              .writeAsBytes(bd!.buffer.asUint8List());
          capturedCount++;
        } catch (_) {}

        final pct = 5 + ((i / totalFrames) * 48).toInt();
        _updateVideoProgress?.call(
            pct, 'Frame ${i + 1} / $totalFrames captured');
      }

      if (capturedCount == 0) throw Exception('No frames captured');

      _updateVideoProgress?.call(54, 'Encoding video with FFmpeg...');

      // ── 2. Frames → MP4 (video only) ──────────────────
      final videoOnlyPath =
          '${directory.path}/vid_only_$timestamp.mp4';

      final String framesCmd =
          '-y -framerate 20 '
          '-i "${framesDir.path}/frame_%04d.png" '
          '-c:v libx264 -preset ultrafast '
          '-pix_fmt yuv420p '
          '-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" '
          '"$videoOnlyPath"';

      final framesSession = await FFmpegKit.execute(framesCmd);
      final framesRC = await framesSession.getReturnCode();

      if (!ReturnCode.isSuccess(framesRC)) {
        final logs = await framesSession.getLogs();
        final msg = logs.map((l) => l.getMessage()).join(' ');
        throw Exception('FFmpeg encode failed: $msg');
      }

      _updateVideoProgress?.call(78, 'Adding audio track...');

      // ── 3. Add audio if music selected ────────────────
      final String finalVideoPath =
          '${directory.path}/post_$timestamp.mp4';

      if (selectedMusic != null &&
          selectedMusic!.localPath != null) {
        final String audioPath = selectedMusic!.localPath!;
        final double trimStart = selectedMusic!.trimStart;
        final double videoDuration = totalFrames / 20.0; // 1.5s
        final double audioDuration = selectedMusic!.trimEnd > 0
            ? (selectedMusic!.trimEnd - trimStart)
            .clamp(0.0, videoDuration)
            : videoDuration;

        final String mergeCmd =
            '-y -i "$videoOnlyPath" '
            '-ss $trimStart -t $audioDuration -i "$audioPath" '
            '-c:v copy -c:a aac -b:a 128k '
            '-map 0:v:0 -map 1:a:0 '
            '-shortest '
            '"$finalVideoPath"';

        final mergeSession = await FFmpegKit.execute(mergeCmd);
        final mergeRC = await mergeSession.getReturnCode();

        if (!ReturnCode.isSuccess(mergeRC)) {
          // Audio merge fail → video only fallback
          await File(videoOnlyPath).copy(finalVideoPath);
        }

        try { await File(videoOnlyPath).delete(); } catch (_) {}

      } else {
        await File(videoOnlyPath).rename(finalVideoPath);
      }

      _updateVideoProgress?.call(96, 'Cleaning up...');

      // ── 4. Cleanup frames directory ───────────────────
      try { await framesDir.delete(recursive: true); } catch (_) {}

      _updateVideoProgress?.call(100, '✅ Done!');
      await Future.delayed(const Duration(milliseconds: 400));

      setState(() { showBottomTools = true; _isCaptureMode = false; });
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      HapticFeedback.heavyImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('✅ Video created!',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
        return finalVideoPath;
      }
      return null;

    } catch (e) {
      setState(() { showBottomTools = true; _isCaptureMode = false; });
      try { await framesDir.delete(recursive: true); } catch (_) {}
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Video error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return null;
    }
  }

  // 🆕 Enhanced Text Input with Caption Preview
  // ✅ FIXED _showTextInput() method
// Replace the entire _showTextInput() method with this

  void _showTextInput() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            // ✅ FIX: Use _textController.text.length directly (not a cached variable)
            final int currentLength = _textController.text.length;
            final bool isOverLimit = currentLength > maxTextLength;
            final bool isEmpty = _textController.text.trim().isEmpty;

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with title and character counter
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEditingText ? 'Edit Text' : 'Add Text',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // ✅ FIX: Counter now reads live from controller
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isOverLimit
                                  ? const Color(0xFFFF3B5C).withOpacity(0.2)
                                  : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isOverLimit
                                    ? const Color(0xFFFF3B5C)
                                    : Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              '$currentLength/$maxTextLength',
                              style: TextStyle(
                                color: isOverLimit
                                    ? const Color(0xFFFF3B5C)
                                    : Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Caption Preview
                      if (_textController.text.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: hasTextBackground
                                ? textBackgroundColor.withOpacity(0.8)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            _textController.text,
                            style: TextStyle(
                              color: textColor,
                              fontSize: fontSize * 0.6,
                              fontFamily: selectedFont,
                              fontWeight:
                              isBold ? FontWeight.bold : FontWeight.normal,
                              fontStyle: isItalic
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              height: 1.45,
                            ),
                            textAlign: currentAlignment,
                            softWrap: true,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      // ✅ FIX: TextField WITHOUT maxLength to avoid Flutter's
                      // built-in counter conflicting with our custom counter
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isOverLimit
                                ? const Color(0xFFFF3B5C)
                                : Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: TextField(
                          controller: _textController,
                          autofocus: true,
                          maxLines: null,
                          // ✅ FIX: Removed maxLength here — we enforce it manually
                          // maxLength: 700,  ← THIS was causing "42/20" display bug
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                          decoration: const InputDecoration(
                            hintText: 'What\'s on your mind?',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                            counterText: '', // Hide any default counter
                          ),
                          onChanged: (text) {
                            // ✅ FIX: Update BOTH modal state AND parent state
                            setModalState(() {}); // Rebuild modal for counter
                            setState(() {
                              currentText = text;
                              hasUnsavedChanges = true;

                              // Auto font size
                              final length = text.length;
                              if (length == 0) {
                                fontSize = 32.0;
                              } else if (length <= 20) {
                                fontSize = 48.0;
                              } else if (length <= 50) {
                                fontSize = 40.0;
                              } else if (length <= 100) {
                                fontSize = 32.0;
                              } else if (length <= 200) {
                                fontSize = 28.0;
                              } else if (length <= 350) {
                                fontSize = 24.0;
                              } else {
                                fontSize = 20.0;
                              }

                              if (isEditingText &&
                                  editingTextIndex != null &&
                                  textElements.isNotEmpty) {
                                textElements[editingTextIndex!].fontSize =
                                    fontSize;
                              }
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        children: [
                          // Cancel Button
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  if (!isEditingText) {
                                    _textController.clear();
                                    currentText = '';
                                  }
                                  isEditingText = false;
                                  editingTextIndex = null;
                                });
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                padding:
                                const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(
                                    color: Colors.white.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.close, size: 18, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // ✅ FIX: Button enabled when text is not empty AND not over limit
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (isOverLimit || isEmpty)
                                  ? null
                                  : () {
                                HapticFeedback.mediumImpact();

                                if (isEditingText &&
                                    editingTextIndex != null) {
                                  // Update existing text
                                  setState(() {
                                    textElements[editingTextIndex!].text =
                                        _textController.text;
                                    textElements[editingTextIndex!]
                                        .fontSize = fontSize;
                                    textElements[editingTextIndex!]
                                        .fontFamily = selectedFont;
                                    textElements[editingTextIndex!].color =
                                        textColor;
                                    textElements[editingTextIndex!].isBold =
                                        isBold;
                                    textElements[editingTextIndex!]
                                        .isItalic = isItalic;
                                    textElements[editingTextIndex!]
                                        .hasBackground = hasTextBackground;
                                    textElements[editingTextIndex!]
                                        .backgroundColor =
                                        textBackgroundColor;
                                    textElements[editingTextIndex!]
                                        .alignment = currentAlignment;

                                    isEditingText = false;
                                    editingTextIndex = null;
                                    hasUnsavedChanges = true;
                                  });
                                  _saveState();

                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text('✅ Text updated!'),
                                      backgroundColor: Color(0xFF10B981),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                } else {
                                  // Add new text
                                  _addTextElement();
                                }

                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (isOverLimit || isEmpty)
                                    ? Colors.grey
                                    : const Color(0xFF10B981),
                                padding:
                                const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isEditingText ? Icons.check : Icons.add,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isEditingText ? 'Done' : 'Add Text',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ).whenComplete(() {
      setState(() {
        if (!isEditingText) {
          _textController.clear();
          currentText = '';
        }
        isEditingText = false;
        editingTextIndex = null;
      });
    });
  }

  void _showFontPicker() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Font',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: availableFonts.length,
                itemBuilder: (context, index) {
                  final font = availableFonts[index];
                  final isSelected = selectedFont == font;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      setState(() {
                        selectedFont = font;
                        hasUnsavedChanges = true;

                        // ✅ දැනටමත් add කරපු LAST text element එකේ font එක update කරනවා
                        if (textElements.isNotEmpty) {
                          textElements.last.fontFamily = font;
                        }
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFF3B5C) : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFF3B5C) : Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Aa',
                            style: TextStyle(
                              fontFamily: font,
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            font,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🆕 Font Size Slider
  void _showFontSizePicker() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Font Size',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontFamily: selectedFont,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('12', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: fontSize,
                        min: 12,
                        max: 72,
                        activeColor: const Color(0xFFFF3B5C),
                        inactiveColor: Colors.white24,
                        onChanged: (value) {
                          setModalState(() {
                            fontSize = value;
                          });
                          setState(() {
                            fontSize = value;
                            hasUnsavedChanges = true;

                            // ✅ දැනටමත් add කරපු LAST text element එකේ size එක update කරනවා
                            if (textElements.isNotEmpty) {
                              textElements.last.fontSize = value;
                            }
                          });
                          HapticFeedback.selectionClick();
                        },
                      ),
                    ),
                    const Text('72', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                Text(
                  '${fontSize.toInt()}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🆕 Enhanced Color Picker with Effects
  void _showColorPicker() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Text Color',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: colorOptions.map((colorOption) {
                final color = colorOption['color'] as Color;
                final effect = colorOption['effect'] as String;
                final isSelected = textColor == color;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      textColor = color;
                      hasUnsavedChanges = true;

                      if (textElements.isNotEmpty) {
                        textElements.last.color = color;

                      }
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
                        width: isSelected ? 4 : 2,
                      ),
                      boxShadow: isSelected || effect != 'none'
                          ? [
                        BoxShadow(
                          color: color.withOpacity(0.6),
                          blurRadius: effect == 'glow' ? 16 : 12,
                          spreadRadius: effect == 'neon' ? 4 : 2,
                        ),
                      ]
                          : [],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 24)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showLayoutOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Layout',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                _buildLayoutOption('Center', 'center', Icons.format_align_center),
                _buildLayoutOption('Left', 'left', Icons.format_align_left),
                _buildLayoutOption('Right', 'right', Icons.format_align_right),
                _buildLayoutOption('Quote', 'quote', Icons.format_quote),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutOption(String label, String layout, IconData icon) {
    final isSelected = selectedLayout == layout;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _changeLayout(layout);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF3B5C) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  void _showStyleOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Text Style',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStyleButton('Bold', Icons.format_bold, isBold, () {
                  setState(() {
                    isBold = !isBold;
                    hasUnsavedChanges = true;

                    // ✅ දැනටමත් add කරපු LAST text element එකේ bold apply කරනවා
                    if (textElements.isNotEmpty) {
                      textElements.last.isBold = isBold;
                    }
                  });
                  HapticFeedback.selectionClick();
                }),
                _buildStyleButton('Italic', Icons.format_italic, isItalic, () {
                  setState(() {
                    isItalic = !isItalic;
                    hasUnsavedChanges = true;

                    // ✅ දැනටමත් add කරපු LAST text element එකේ italic apply කරනවා
                    if (textElements.isNotEmpty) {
                      textElements.last.isItalic = isItalic;
                    }
                  });
                  HapticFeedback.selectionClick();
                }),  _buildStyleButton('Italic', Icons.format_italic, isItalic, () {
                  setState(() {
                    isItalic = !isItalic;
                    hasUnsavedChanges = true;
                  });
                  HapticFeedback.selectionClick();
                }),
              ],
            ),
            const SizedBox(height: 12),
            _buildStyleButton(
              'Background',
              Icons.border_color,
              hasTextBackground,
                  () {
                setState(() {
                  hasTextBackground = !hasTextBackground;
                  hasUnsavedChanges = true;

                  // ✅ දැනටමත් add කරපු LAST text element එකේ background apply කරනවා
                  if (textElements.isNotEmpty) {
                    textElements.last.hasBackground = hasTextBackground;
                    textElements.last.backgroundColor = textBackgroundColor;
                  }
                });
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleButton(String label, IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFF3B5C) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFFFF3B5C) : Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🆕 Enhanced Emoji & Sticker Picker with Tabs
  void _showEmojiAndStickerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DefaultTabController(
        length: 2,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              TabBar(
                indicatorColor: const Color(0xFFFF3B5C),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.emoji_emotions),
                    text: 'Emojis',
                  ),
                  Tab(
                    icon: Icon(Icons.auto_awesome),
                    text: 'Stickers',
                  ),
                ],
              ),

              Expanded(
                child: TabBarView(
                  children: [
                    // Emojis Tab
                    _buildEmojiGrid(),

                    // Stickers Tab
                    _buildStickerGrid(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiGrid() {
    final emojis = [
      '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂',
      '😍', '🥰', '😘', '😗', '😙', '😚', '🤗', '🤩',
      '🤔', '🤨', '😐', '😑', '😶', '🙄', '😏', '😣',
      '🔥', '❤️', '💯', '💥', '✨', '🌟', '⭐', '💫',
      '👍', '👎', '👊', '✊', '🤝', '👏', '🙏', '💪',
      '🎉', '🎊', '🎈', '🎁', '🏆', '🥇', '🥈', '🥉',
      '🎯', '🎮', '🎲', '🎰', '🎸', '🎹', '🎤', '🎧',
      '⚽', '🏀', '🏈', '⚾', '🎾', '🏐', '🏓', '🏸',
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            _addEmoji(emojis[index]);
            Navigator.pop(context);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                emojis[index],
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStickerGrid() {
    // 🆕 JSON Stickers from assets
    final stickerAssets = [
      'assets/stickers/anatomical-heart.json',
      'assets/stickers/bouquet.json',
      'assets/stickers/clinking-glasses.json',
      'assets/stickers/clown.json',
      'assets/stickers/dancer-woman.json',
      'assets/stickers/disguise.json',
      'assets/stickers/drum.json',
      'assets/stickers/fire-heart.json',
      'assets/stickers/glowing-star.json',
      'assets/stickers/hand-with-index-finger-and-thumb-crossed.json',
      'assets/stickers/heart-balloons.json',
      'assets/stickers/rubber-duck.json',
      'assets/stickers/saxophone.json',
      'assets/stickers/social-media-like.json',
      'assets/stickers/star.json',
      'assets/stickers/violin.json',
      'assets/stickers/volcano.json',
      'assets/stickers/xmas-star.json',
      'assets/stickers/successfully-done.json',
      'assets/stickers/astronot.json',
      'assets/stickers/couple-taking-photo.json'
          'assets/stickers/kiss.json'
          'assets/stickers/bouquet (1).json'
          'assets/stickers/winne-the-pooh.json'
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: stickerAssets.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            _addSticker(stickerAssets[index]);
            Navigator.pop(context);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Center(
              child: Lottie.asset(
                stickerAssets[index],
                width: 60,
                height: 60,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.auto_awesome,
                    color: Colors.white54,
                    size: 40,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // 🆕 Background Options (Gradient or Gallery)
  void _showBackgroundOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Background',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Gallery Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF667EEA).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library, color: Color(0xFF667EEA)),
              ),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickBackgroundImage();
              },
            ),

            // Remove Background Option
            if (_backgroundImage != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B5C).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close, color: Color(0xFFFF3B5C)),
                ),
                title: const Text(
                  'Remove Background Image',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removeBackgroundImage();
                },
              ),

            const Divider(color: Colors.white24),

            // Gradient Presets
            const Text(
              'Gradient Presets',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: backgroundGradients.length,
                itemBuilder: (context, index) {
                  final isSelected = selectedBackgroundIndex == index && _backgroundImage == null;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedBackgroundIndex = index;
                        _backgroundImage = null;
                        hasUnsavedChanges = true;
                      });
                      _saveState();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: backgroundGradients[index],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🆕 Poll Creator
  void _showPollCreator() {
    final questionController = TextEditingController();
    final option1Controller = TextEditingController();
    final option2Controller = TextEditingController();
    final option3Controller = TextEditingController();
    final option4Controller = TextEditingController();

    int? selectedCorrectAnswer;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Create Poll',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Question Input
                    TextField(
                      controller: questionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ask a question...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Options (Select the correct answer)',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 12),

                    // Option 1
                    _buildPollOptionInput(
                      controller: option1Controller,
                      optionNumber: 1,
                      isCorrect: selectedCorrectAnswer == 0,
                      onTap: () {
                        setModalState(() {
                          selectedCorrectAnswer = 0;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Option 2
                    _buildPollOptionInput(
                      controller: option2Controller,
                      optionNumber: 2,
                      isCorrect: selectedCorrectAnswer == 1,
                      onTap: () {
                        setModalState(() {
                          selectedCorrectAnswer = 1;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Option 3
                    _buildPollOptionInput(
                      controller: option3Controller,
                      optionNumber: 3,
                      isCorrect: selectedCorrectAnswer == 2,
                      onTap: () {
                        setModalState(() {
                          selectedCorrectAnswer = 2;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Option 4
                    _buildPollOptionInput(
                      controller: option4Controller,
                      optionNumber: 4,
                      isCorrect: selectedCorrectAnswer == 3,
                      onTap: () {
                        setModalState(() {
                          selectedCorrectAnswer = 3;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Create Poll Button
                    ElevatedButton(
                      onPressed: () {
                        if (questionController.text.isNotEmpty &&
                            option1Controller.text.isNotEmpty &&
                            option2Controller.text.isNotEmpty &&
                            option3Controller.text.isNotEmpty &&
                            option4Controller.text.isNotEmpty &&
                            selectedCorrectAnswer != null) {

                          setState(() {
                            activePoll = PollQuestion(
                              question: questionController.text,
                              options: [
                                option1Controller.text,
                                option2Controller.text,
                                option3Controller.text,
                                option4Controller.text,
                              ],
                              correctAnswerIndex: selectedCorrectAnswer!,
                            );
                            hasUnsavedChanges = true;
                          });
                          _saveState();
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Poll created with 4 options!'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('⚠️ Fill all fields & select correct answer'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Create Poll'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  Widget _buildPollOptionInput({
    required TextEditingController controller,
    required int optionNumber,
    required bool isCorrect,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCorrect ? const Color(0xFF10B981) : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: isCorrect ? const Color(0xFF10B981) : Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: isCorrect
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(
                '$optionNumber',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Option $optionNumber',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: isCorrect
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
  void _showMusicPicker() {
    HapticFeedback.selectionClick();

    if (isMusicPlaying) {
      _musicPlayer.stop();
      setState(() {
        isMusicPlaying = false;
      });
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AudioPickerImproved(
        onAudioSelected: (AudioTrackEnhanced? track) async {
          setState(() {
            selectedMusic = track;
            hasUnsavedChanges = true;
          });

          if (track != null) {
            HapticFeedback.mediumImpact();

            if (track.localPath != null) {
              try {
                await _musicPlayer.setSource(DeviceFileSource(track.localPath!));

                if (track.trimStart > 0) {
                  await _musicPlayer.seek(Duration(seconds: track.trimStart.toInt()));
                }

                await _musicPlayer.resume();

                setState(() {
                  isMusicPlaying = true;
                });

                if (track.trimEnd > 0) {
                  final playDuration = track.trimEnd - track.trimStart;
                  Future.delayed(Duration(seconds: playDuration.toInt()), () {
                    if (isMusicPlaying && mounted) {
                      _musicPlayer.pause();
                      setState(() {
                        isMusicPlaying = false;
                      });
                    }
                  });
                }
              } catch (e) {
                print('Error playing music: $e');
              }
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.music_note, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🎵 ${track.title} - ${track.artist}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 3),
                backgroundColor: const Color(0xFFFF3B5C),
              ),
            );
          }
        },
      ),
    );
  }
}

// Models
class DraggableText {
  String text;
  Offset position;
  double scale;
  double rotation;
  double fontSize;
  String fontFamily;
  Color color;
  bool isBold;
  bool isItalic;
  bool hasBackground;
  Color backgroundColor;
  TextAlign alignment;

  DraggableText({
    required this.text,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    required this.fontSize,
    required this.fontFamily,
    required this.color,
    required this.isBold,
    required this.isItalic,
    required this.hasBackground,
    required this.backgroundColor,
    required this.alignment,
  });
}

class DraggableEmoji {
  String emoji;
  Offset position;
  double scale;
  double rotation;

  DraggableEmoji({
    required this.emoji,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
  });
}

class DraggableSticker {
  String assetPath;
  Offset position;
  double scale;
  double rotation;

  DraggableSticker({
    required this.assetPath,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
  });
}

class PollQuestion {
  String question;
  List<String> options;
  int correctAnswerIndex;

  PollQuestion({
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
  });
}

class EditorState {
  List<DraggableText> textElements;
  List<DraggableEmoji> emojis;
  List<DraggableSticker> stickers;
  PollQuestion? activePoll;
  int backgroundIndex;
  File? backgroundImage;

  EditorState({
    required this.textElements,
    required this.emojis,
    required this.stickers,
    this.activePoll,
    required this.backgroundIndex,
    this.backgroundImage,
  });
}

class MeshGradientPainter extends CustomPainter {
  final Animation<double> animation;
  final List<Color> colors;

  MeshGradientPainter({required this.animation, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    for (int i = 0; i < 2; i++) {
      final centerX = size.width * (0.3 + i * 0.4);
      final centerY = size.height * (0.3 + math.sin(animation.value * math.pi + i) * 0.2);
      final radius = size.width * (0.35 + math.cos(animation.value * math.pi) * 0.1);

      paint.color = colors[i % colors.length].withOpacity(0.25);

      canvas.drawCircle(
        Offset(centerX, centerY),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(MeshGradientPainter oldDelegate) => true;
}

class FinalPostPage extends StatefulWidget {
  final String imagePath;
  final AudioTrackEnhanced? selectedMusic;
  final bool hasPoll;
  final bool isAnimated; // ✅ New parameter

  const FinalPostPage({
    super.key,
    required this.imagePath,
    this.selectedMusic,
    this.hasPoll = false,
    this.isAnimated = false, // ✅ Default value
  });

  @override
  State<FinalPostPage> createState() => _FinalPostPageState();
}

class _FinalPostPageState extends State<FinalPostPage> {
  final TextEditingController _captionController = TextEditingController();
  final int maxCaptionLength = 2200;

  final List<Color> backgroundColors = [
    Colors.white,
    const Color(0xFFF3F4F6),
    const Color(0xFFFFE4E6),
    const Color(0xFFE0E7FF),
    const Color(0xFFDCFCE7),
    const Color(0xFFFEF3C7),
  ];

  int selectedColorIndex = 0;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  @override
  void initState() {
    super.initState();
    _videoController = null;
    _isVideoInitialized = false;

    if (widget.imagePath.endsWith('.mp4')) {
      _videoController = VideoPlayerController.file(
        File(widget.imagePath),
      )..initialize().then((_) {
        if (mounted) {
          setState(() => _isVideoInitialized = true);
          _videoController!.setLooping(true);
          _videoController!.play();
        }
      }).catchError((e) {
        if (mounted) setState(() => _isVideoInitialized = false);
      });
    }
  }
  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_captionController.text.isEmpty) {
      return true;
    }

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Discard Caption?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Your caption will be lost.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF3B5C),
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _handlePost() async {
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Post created successfully!'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );

    Navigator.pop(context, true);
  }

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FULL UPDATED build() METHOD — copy paste කරන්න:
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: backgroundColors[selectedColorIndex],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop) Navigator.pop(context);
            },
          ),
          title: const Text(
            'New Post',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextButton(
                onPressed: _handlePost,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Post',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ✅ CHANGED: Stack+ClipRRect → _buildMediaPreview()
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildMediaPreview(),
              ),

              const SizedBox(height: 20),

              if (widget.selectedMusic != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B5C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF3B5C).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B5C),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.selectedMusic!.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.selectedMusic!.artist,
                                style: TextStyle(
                                  color: Colors.black.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (widget.hasPoll)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667EEA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF667EEA).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF667EEA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.poll,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Poll included',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _captionController,
                        maxLines: 6,
                        maxLength: maxCaptionLength,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Write a caption...',
                          hintStyle: TextStyle(
                            color: Colors.black.withOpacity(0.4),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          counterStyle: TextStyle(
                            color: Colors.black.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                        onChanged: (text) {
                          setState(() {});
                        },
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.05),
                          border: Border(
                            top: BorderSide(
                              color: Colors.grey.withOpacity(0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            _buildQuickAction(Icons.alternate_email, 'Mention'),
                            const SizedBox(width: 12),
                            _buildQuickAction(Icons.tag, 'Hashtag'),
                            const Spacer(),
                            Text(
                              '${_captionController.text.length}/$maxCaptionLength',
                              style: TextStyle(
                                color: _captionController.text.length > maxCaptionLength * 0.9
                                    ? const Color(0xFFFF3B5C)
                                    : Colors.black.withOpacity(0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Background Color',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: backgroundColors.length,
                        itemBuilder: (context, index) {
                          final isSelected = selectedColorIndex == index;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                selectedColorIndex = index;
                              });
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: backgroundColors[index],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF10B981)
                                      : Colors.grey.withOpacity(0.3),
                                  width: isSelected ? 3 : 2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                                    : [],
                              ),
                              child: isSelected
                                  ? const Icon(
                                Icons.check,
                                color: Color(0xFF10B981),
                                size: 24,
                              )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// STEP 2: _buildMediaPreview() method ADD කරන්න
// _buildQuickAction() method එකට පස්සේ, class close } කලින්
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildMediaPreview() {
    final bool isVideo = widget.imagePath.endsWith('.mp4');

    if (isVideo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ✅ Actual video or loading
            _isVideoInitialized && _videoController != null
                ? GestureDetector(
              onTap: () {
                setState(() {
                  _videoController!.value.isPlaying
                      ? _videoController!.pause()
                      : _videoController!.play();
                });
              },
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            )
                : Container(
              width: double.infinity,
              height: 400,
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF3B5C),
                  strokeWidth: 3,
                ),
              ),
            ),

            // ✅ Play/Pause overlay — playing නම් fade out
            if (_isVideoInitialized && _videoController != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _videoController!.value.isPlaying
                        ? _videoController!.pause()
                        : _videoController!.play();
                  });
                },
                child: AnimatedOpacity(
                  opacity: _videoController!.value.isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),

            // ✅ Video badge
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B5C).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'Video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ✅ Sound badge
            if (widget.selectedMusic != null)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.music_note, color: Colors.white, size: 13),
                      SizedBox(width: 4),
                      Text(
                        'Sound',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // ✅ GIF / PNG
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Image.file(
            File(widget.imagePath),
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          if (widget.isAnimated)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B5C).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gif_box, color: Colors.white, size: 18),
                    SizedBox(width: 4),
                    Text(
                      'Animated',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
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

  Widget _buildQuickAction(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();

        final currentText = _captionController.text;
        final selection = _captionController.selection;
        final newText = currentText.replaceRange(
          selection.start,
          selection.end,
          label == 'Mention' ? '@' : '#',
        );

        _captionController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(
            offset: selection.start + 1,
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              label == 'Mention'
                  ? '💡 Type username after @'
                  : '💡 Type tag after #',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF667EEA),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.black.withOpacity(0.6)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }





}