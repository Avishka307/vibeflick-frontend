import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

import 'face_effects_painter.dart';

class CameraFaceEffectsScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraFaceEffectsScreen({Key? key, required this.cameras})
      : super(key: key);

  @override
  State<CameraFaceEffectsScreen> createState() =>
      _CameraFaceEffectsScreenState();
}

class _CameraFaceEffectsScreenState extends State<CameraFaceEffectsScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  List<Face> _faces = [];
  bool _isDetecting = false;
  bool _isRecording = false;
  String? _selectedEffect;
  int _selectedCameraIndex = 0;

  // Animation controllers for smooth transitions
  late AnimationController _effectTransitionController;
  late AnimationController _recordingPulseController;

  // Effect categories
  final Map<String, List<Map<String, dynamic>>> _effectCategories = {
    'Animals': [
      {
        'id': 'dog',
        'name': 'Classic Dog',
        'asset': 'assets/effects/dog.png',
        'icon': Icons.pets
      },
      {
        'id': 'cat',
        'name': 'Cute Cat',
        'asset': 'assets/effects/dog.png',
        'icon': Icons.pets_outlined
      },
      {
        'id': 'rabbit',
        'name': 'Rabbit',
        'asset': 'assets/effects/dog.png',
        'icon': Icons.cruelty_free
      },
      {
        'id': 'lion',
        'name': 'Lion',
        'asset': 'assets/effects/dog.png',
        'icon': Icons.face
      },
      {
        'id': 'panda',
        'name': 'Panda',
        'asset': 'assets/effects/dog.png',
        'icon': Icons.face
      },
      {
        'id': 'monkey',
        'name': 'Monkey',
        'asset': 'assets/effects/dog.png',
        'icon': Icons.face
      },
      {
        'id': 'bee',
        'name': 'Bee',
        'asset': 'assets/effects/dog.png',
        'icon': Icons.face
      },
    ],
    'Beauty': [
      {
        'id': 'cool_shades',
        'name': 'Cool Shades',
        'asset': 'assets/effects/dog.png',
        'icon': Icons.sunny
      },
      {
        'id': 'flower_crown',
        'name': 'Flower Crown',
        'asset': 'assets/effects/dog.png',
        'icon': Icons.local_florist
      },
      {
        'id': 'butterfly',
        'name': 'Butterfly',
        'asset': 'assets/effects/dog.png',
        'icon': Icons.flutter_dash
      },
      {
        'id': 'neon_crown',
        'name': 'Neon Crown',
        'asset': 'assets/effects/dog.png',
        'icon': Icons.auto_awesome
      },
      {
        'id': 'star_freckles',
        'name': 'Star Freckles',
        'asset': 'assets/effects/dog.png',
        'icon': Icons.star
      },
      {
        'id': 'lipstick',
        'name': 'Lipstick',
        'asset': 'assets/effects/dog.png',
        'icon': Icons.face
      },
    ],
    'Creative': [
      {
        'id': 'devil_horns',
        'name': 'Devil Horns',
        'asset': 'assets/effects/dog.png',
        'icon': Icons.whatshot
      },
      {
        'id': 'fire_eyes',
        'name': 'Fire Eyes',
        'asset': 'assets/effects/dog.png',
        'icon': Icons.local_fire_department
      },
      {
        'id': 'ghost',
        'name': 'Ghost',
      'asset': 'assets/effects/dog.png',
        'icon': Icons.emoji_emotions_outlined
      },
      {
        'id': 'cyberpunk',
        'name': 'Cyberpunk',
        'asset': 'assets/effects/dog.png',
        'icon': Icons.smart_toy
      },
      {
        'id': 'halo_wings',
        'name': 'Angel',
        'asset': 'assets/effects/dog.png',
        'icon': Icons.favorite
      },
    ],
  };

  String _selectedCategory = 'Animals';

  // Loaded images cache
  final Map<String, ui.Image> _loadedImages = {};
  bool _isLoadingEffects = true;

  @override
  void initState() {
    super.initState();

    _effectTransitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _recordingPulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _initializeCamera();
    _initializeFaceDetector();
    _preloadEffectImages();
  }

  Future<void> _initializeCamera() async {
    _cameraController = CameraController(
      widget.cameras[_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController!.initialize();
    _cameraController!.startImageStream(_processCameraImage);

    if (mounted) {
      setState(() {});
    }
  }

  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15,
    );
    _faceDetector = FaceDetector(options: options);
  }

  // Pre-load PNG images for smooth rendering
  Future<void> _preloadEffectImages() async {
    setState(() {
      _isLoadingEffects = true;
    });

    try {
      // Load all effect images from assets
      for (var category in _effectCategories.values) {
        for (var effect in category) {
          if (effect['asset'] != null) {
            try {
              final ByteData data = await rootBundle.load(effect['asset']);
              final Uint8List bytes = data.buffer.asUint8List();
              final ui.Codec codec = await ui.instantiateImageCodec(bytes);
              final ui.FrameInfo frameInfo = await codec.getNextFrame();
              _loadedImages[effect['id']] = frameInfo.image;
            } catch (e) {
              print('⚠️ Failed to load ${effect['id']}: $e');
              // If asset fails, we'll use the painter fallback
            }
          }
        }
      }
    } catch (e) {
      print('Error preloading effects: $e');
    }

    setState(() {
      _isLoadingEffects = false;
    });
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize =
      Size(image.width.toDouble(), image.height.toDouble());

      final InputImageRotation imageRotation =
          InputImageRotationValue.fromRawValue(
              _cameraController!.description.sensorOrientation) ??
              InputImageRotation.rotation0deg;

      final InputImageFormat inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
              InputImageFormat.nv21;

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      final faces = await _faceDetector!.processImage(inputImage);

      if (mounted) {
        setState(() {
          _faces = faces;
        });
      }
    } catch (e) {
      print('Error processing image: $e');
    }

    _isDetecting = false;
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final XFile video = await _cameraController!.stopVideoRecording();
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String savePath =
          '${appDir.path}/effect_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      await File(video.path).copy(savePath);

      setState(() {
        _isRecording = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎬 Video saved with effects!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> _flipCamera() async {
    setState(() {
      _selectedCameraIndex = _selectedCameraIndex == 0 ? 1 : 0;
    });

    await _cameraController?.dispose();
    await _initializeCamera();
  }

  void _selectEffect(String effectId) {
    setState(() {
      _selectedEffect = _selectedEffect == effectId ? null : effectId;
    });

    _effectTransitionController.forward().then((_) {
      _effectTransitionController.reverse();
    });

    if (_selectedEffect != null) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview with Effects
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Camera feed
                CameraPreview(_cameraController!),

                // Face Effects Overlay
                if (_selectedEffect != null && !_isLoadingEffects)
                  CustomPaint(
                    painter: FaceEffectsPainter(
                      faces: _faces,
                      imageSize: Size(
                        _cameraController!.value.previewSize!.height,
                        _cameraController!.value.previewSize!.width,
                      ),
                      effectId: _selectedEffect!,
                      effectImage: _loadedImages[_selectedEffect],
                      isFrontCamera: _selectedCameraIndex == 1,
                    ),
                  ),

                // Loading indicator for effects
                if (_isLoadingEffects && _selectedEffect != null)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
              ],
            ),
          ),

          // Top Controls
          _buildTopControls(),

          // Recording Indicator
          if (_isRecording) _buildRecordingIndicator(),

          // Bottom Effects Selector
          _buildEffectsSelector(),

          // Record Button
          _buildRecordButton(),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 24),
            ),
            onPressed: () => Navigator.pop(context),
          ),

          // Flip camera button
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cameraswitch, color: Colors.white, size: 24),
            ),
            onPressed: _flipCamera,
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _recordingPulseController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.7 + (_recordingPulseController.value * 0.3)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'REC',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEffectsSelector() {
    return Positioned(
      bottom: 140,
      left: 0,
      right: 0,
      child: Column(
        children: [
          // Category selector
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _effectCategories.keys.map((category) {
                final isSelected = _selectedCategory == category;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                    HapticFeedback.selectionClick();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFF3B5C)
                          : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(isSelected ? 1.0 : 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Effects list
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _effectCategories[_selectedCategory]!.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildEffectItem(null, 'None', Icons.block);
                }
                final effect = _effectCategories[_selectedCategory]![index - 1];
                return _buildEffectItem(
                  effect['id'],
                  effect['name'],
                  effect['icon'],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEffectItem(String? effectId, String name, IconData icon) {
    final isSelected = _selectedEffect == effectId;
    return GestureDetector(
      onTap: () => _selectEffect(effectId ?? ''),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.1).animate(
                CurvedAnimation(
                  parent: _effectTransitionController,
                  curve: Curves.easeInOut,
                ),
              ),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected
                      ? const LinearGradient(
                    colors: [Color(0xFFFF3B5C), Color(0xFFFF6B8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  color: isSelected ? null : Colors.white.withOpacity(0.2),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color: const Color(0xFFFF3B5C).withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                      : null,
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: _toggleRecording,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              gradient: _isRecording
                  ? const LinearGradient(
                colors: [Colors.red, Colors.redAccent],
              )
                  : LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.1),
                ],
              ),
            ),
            child: _isRecording
                ? const Icon(Icons.stop, color: Colors.white, size: 32)
                : null,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector?.close();
    _effectTransitionController.dispose();
    _recordingPulseController.dispose();

    // Dispose loaded images
    for (var image in _loadedImages.values) {
      image.dispose();
    }

    super.dispose();
  }
}