import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceEffectsPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final String effectId;
  final ui.Image? effectImage; // PNG image for the effect
  final bool isFrontCamera;

  FaceEffectsPainter({
    required this.faces,
    required this.imageSize,
    required this.effectId,
    this.effectImage,
    this.isFrontCamera = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty) return;

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    for (final face in faces) {
      _drawEffect(canvas, face, scaleX, scaleY, size);
    }
  }

  void _drawEffect(Canvas canvas, Face face, double scaleX, double scaleY, Size size) {
    // Use PNG image if available, otherwise fallback to custom painting
    if (effectImage != null) {
      _drawImageEffect(canvas, face, scaleX, scaleY, effectImage!);
    } else {
      _drawCustomEffect(canvas, face, scaleX, scaleY, size);
    }
  }

  // Draw PNG image effect with proper positioning and rotation
  void _drawImageEffect(Canvas canvas, Face face, double scaleX, double scaleY, ui.Image image) {
    final rect = face.boundingBox;
    final faceCenter = Offset(rect.center.dx * scaleX, rect.center.dy * scaleY);
    final faceWidth = rect.width * scaleX;
    final faceHeight = rect.height * scaleY;

    // Get face rotation angle
    final double rotY = face.headEulerAngleY ?? 0.0; // Left-right rotation
    final double rotZ = face.headEulerAngleZ ?? 0.0; // Tilt rotation
    final double rotX = face.headEulerAngleX ?? 0.0; // Up-down rotation

    canvas.save();

    // Apply transformations based on effect type
    switch (effectId) {
      case 'dog':
      case 'cat':
      case 'rabbit':
      case 'lion':
      case 'panda':
      case 'monkey':
      case 'bee':
        _drawAnimalEffect(canvas, face, scaleX, scaleY, image, rotY, rotZ, rotX);
        break;

      case 'cool_shades':
        _drawGlassesEffect(canvas, face, scaleX, scaleY, image, rotY, rotZ);
        break;

      case 'flower_crown':
      case 'neon_crown':
        _drawCrownEffect(canvas, face, scaleX, scaleY, image, rotY, rotZ);
        break;

      case 'devil_horns':
        _drawHornsEffect(canvas, face, scaleX, scaleY, image, rotY, rotZ);
        break;

      case 'butterfly':
        _drawButterflyEffect(canvas, face, scaleX, scaleY, image);
        break;

      case 'fire_eyes':
        _drawEyesEffect(canvas, face, scaleX, scaleY, image);
        break;

      case 'lipstick':
        _drawLipstickEffect(canvas, face, scaleX, scaleY, image);
        break;

      case 'halo_wings':
        _drawAngelEffect(canvas, face, scaleX, scaleY, image, rotY);
        break;

      default:
        _drawFullFaceEffect(canvas, face, scaleX, scaleY, image, rotY, rotZ);
        break;
    }

    canvas.restore();
  }

  // Animal effects - cover full face with ears
  void _drawAnimalEffect(Canvas canvas, Face face, double scaleX, double scaleY,
      ui.Image image, double rotY, double rotZ, double rotX) {
    final rect = face.boundingBox;
    final faceCenter = Offset(rect.center.dx * scaleX, rect.center.dy * scaleY);
    final faceWidth = rect.width * scaleX * 1.4; // Slightly larger than face
    final faceHeight = rect.height * scaleY * 1.4;

    canvas.save();
    canvas.translate(faceCenter.dx, faceCenter.dy);

    // Apply 3D rotation
    canvas.rotate(rotZ * pi / 180); // Tilt

    // Scale based on Y rotation (creates 3D perspective)
    final perspectiveScale = 1.0 - (rotY.abs() / 180) * 0.3;

    // Flip horizontally if front camera
    if (isFrontCamera) {
      canvas.scale(-1.0 * perspectiveScale, perspectiveScale);
    } else {
      canvas.scale(perspectiveScale, 1.0);
    }

    // Draw the image centered
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromCenter(
      center: Offset.zero,
      width: faceWidth,
      height: faceHeight,
    );

    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    // Add shadow for depth
    canvas.drawShadow(
      Path()..addOval(dstRect.inflate(10)),
      Colors.black.withOpacity(0.3),
      8.0,
      false,
    );

    canvas.drawImageRect(image, srcRect, dstRect, paint);
    canvas.restore();
  }

  // Glasses/Shades effect - position on eyes
  void _drawGlassesEffect(Canvas canvas, Face face, double scaleX, double scaleY,
      ui.Image image, double rotY, double rotZ) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];

    if (leftEye == null || rightEye == null) return;

    final leftPos = _pointToOffset(leftEye.position, scaleX, scaleY);
    final rightPos = _pointToOffset(rightEye.position, scaleX, scaleY);
    final eyeCenter = Offset(
      (leftPos.dx + rightPos.dx) / 2,
      (leftPos.dy + rightPos.dy) / 2,
    );

    final eyeDistance = (rightPos - leftPos).distance;
    final glassesWidth = eyeDistance * 2.2;
    final glassesHeight = glassesWidth * 0.4;

    canvas.save();
    canvas.translate(eyeCenter.dx, eyeCenter.dy);
    canvas.rotate(rotZ * pi / 180);

    if (isFrontCamera) {
      canvas.scale(-1.0, 1.0);
    }

    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromCenter(
      center: Offset.zero,
      width: glassesWidth,
      height: glassesHeight,
    );

    canvas.drawImageRect(
      image,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.high,
    );

    canvas.restore();
  }

  // Crown effect - position above head
  void _drawCrownEffect(Canvas canvas, Face face, double scaleX, double scaleY,
      ui.Image image, double rotY, double rotZ) {
    final rect = face.boundingBox;
    final headTop = Offset(rect.center.dx * scaleX, rect.top * scaleY);
    final faceWidth = rect.width * scaleX;

    canvas.save();
    canvas.translate(headTop.dx, headTop.dy - faceWidth * 0.3);
    canvas.rotate(rotZ * pi / 180);

    if (isFrontCamera) {
      canvas.scale(-1.0, 1.0);
    }

    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromCenter(
      center: Offset.zero,
      width: faceWidth * 1.3,
      height: faceWidth * 0.7,
    );

    canvas.drawImageRect(
      image,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.high,
    );

    canvas.restore();
  }

  // Devil horns - position at top corners
  void _drawHornsEffect(Canvas canvas, Face face, double scaleX, double scaleY,
      ui.Image image, double rotY, double rotZ) {
    final rect = face.boundingBox;
    final faceWidth = rect.width * scaleX;

    // Left horn
    canvas.save();
    canvas.translate(rect.left * scaleX, rect.top * scaleY - faceWidth * 0.1);
    canvas.rotate(rotZ * pi / 180);

    if (isFrontCamera) {
      canvas.scale(-1.0, 1.0);
    }

    final hornSize = faceWidth * 0.4;
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromCenter(
      center: Offset.zero,
      width: hornSize,
      height: hornSize,
    );

    canvas.drawImageRect(image, srcRect, dstRect, Paint()..filterQuality = FilterQuality.high);
    canvas.restore();

    // Right horn
    canvas.save();
    canvas.translate(rect.right * scaleX, rect.top * scaleY - faceWidth * 0.1);
    canvas.rotate(rotZ * pi / 180);

    if (isFrontCamera) {
      canvas.scale(-1.0, 1.0);
    }

    canvas.drawImageRect(image, srcRect, dstRect, Paint()..filterQuality = FilterQuality.high);
    canvas.restore();
  }

  // Butterfly on nose
  void _drawButterflyEffect(Canvas canvas, Face face, double scaleX, double scaleY, ui.Image image) {
    final noseBase = face.landmarks[FaceLandmarkType.noseBase];
    if (noseBase == null) return;

    final nosePos = _pointToOffset(noseBase.position, scaleX, scaleY);
    final faceWidth = face.boundingBox.width * scaleX;

    canvas.save();
    canvas.translate(nosePos.dx, nosePos.dy - faceWidth * 0.15);

    if (isFrontCamera) {
      canvas.scale(-1.0, 1.0);
    }

    final size = faceWidth * 0.5;
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromCenter(
      center: Offset.zero,
      width: size,
      height: size * 0.7,
    );

    canvas.drawImageRect(image, srcRect, dstRect, Paint()..filterQuality = FilterQuality.high);
    canvas.restore();
  }

  // Fire eyes effect
  void _drawEyesEffect(Canvas canvas, Face face, double scaleX, double scaleY, ui.Image image) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];

    if (leftEye == null || rightEye == null) return;

    final leftPos = _pointToOffset(leftEye.position, scaleX, scaleY);
    final rightPos = _pointToOffset(rightEye.position, scaleX, scaleY);
    final eyeSize = face.boundingBox.width * scaleX * 0.2;

    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

    // Left eye
    canvas.save();
    canvas.translate(leftPos.dx, leftPos.dy);
    if (isFrontCamera) canvas.scale(-1.0, 1.0);
    canvas.drawImageRect(
      image,
      srcRect,
      Rect.fromCenter(center: Offset.zero, width: eyeSize, height: eyeSize),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();

    // Right eye
    canvas.save();
    canvas.translate(rightPos.dx, rightPos.dy);
    if (isFrontCamera) canvas.scale(-1.0, 1.0);
    canvas.drawImageRect(
      image,
      srcRect,
      Rect.fromCenter(center: Offset.zero, width: eyeSize, height: eyeSize),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  // Lipstick on mouth
  void _drawLipstickEffect(Canvas canvas, Face face, double scaleX, double scaleY, ui.Image image) {
    final bottomMouth = face.landmarks[FaceLandmarkType.bottomMouth];
    if (bottomMouth == null) return;

    final mouthPos = _pointToOffset(bottomMouth.position, scaleX, scaleY);
    final faceWidth = face.boundingBox.width * scaleX;

    canvas.save();
    canvas.translate(mouthPos.dx, mouthPos.dy);

    if (isFrontCamera) {
      canvas.scale(-1.0, 1.0);
    }

    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromCenter(
      center: Offset.zero,
      width: faceWidth * 0.4,
      height: faceWidth * 0.2,
    );

    canvas.drawImageRect(image, srcRect, dstRect, Paint()..filterQuality = FilterQuality.high);
    canvas.restore();
  }

  // Angel effect - halo and wings
  void _drawAngelEffect(Canvas canvas, Face face, double scaleX, double scaleY,
      ui.Image image, double rotY) {
    final rect = face.boundingBox;
    final faceCenter = Offset(rect.center.dx * scaleX, rect.center.dy * scaleY);
    final faceWidth = rect.width * scaleX;

    // Draw halo
    canvas.save();
    canvas.translate(faceCenter.dx, rect.top * scaleY - faceWidth * 0.4);
    if (isFrontCamera) canvas.scale(-1.0, 1.0);

    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final haloSize = faceWidth * 0.8;

    canvas.drawImageRect(
      image,
      srcRect,
      Rect.fromCenter(center: Offset.zero, width: haloSize, height: haloSize * 0.3),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();

    // Draw wings (you can have a separate wings image or use the same)
    // Left wing
    canvas.save();
    canvas.translate(rect.left * scaleX - faceWidth * 0.3, faceCenter.dy);
    if (isFrontCamera) canvas.scale(-1.0, 1.0);

    final wingSize = faceWidth * 0.7;
    canvas.drawImageRect(
      image,
      srcRect,
      Rect.fromCenter(center: Offset.zero, width: wingSize, height: wingSize * 1.2),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();

    // Right wing
    canvas.save();
    canvas.translate(rect.right * scaleX + faceWidth * 0.3, faceCenter.dy);
    if (isFrontCamera) canvas.scale(-1.0, 1.0);
    canvas.scale(-1.0, 1.0); // Flip the wing

    canvas.drawImageRect(
      image,
      srcRect,
      Rect.fromCenter(center: Offset.zero, width: wingSize, height: wingSize * 1.2),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  // Full face overlay
  void _drawFullFaceEffect(Canvas canvas, Face face, double scaleX, double scaleY,
      ui.Image image, double rotY, double rotZ) {
    final rect = face.boundingBox;
    final faceCenter = Offset(rect.center.dx * scaleX, rect.center.dy * scaleY);
    final faceWidth = rect.width * scaleX * 1.2;
    final faceHeight = rect.height * scaleY * 1.2;

    canvas.save();
    canvas.translate(faceCenter.dx, faceCenter.dy);
    canvas.rotate(rotZ * pi / 180);

    if (isFrontCamera) {
      canvas.scale(-1.0, 1.0);
    }

    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromCenter(
      center: Offset.zero,
      width: faceWidth,
      height: faceHeight,
    );

    canvas.drawImageRect(image, srcRect, dstRect, Paint()..filterQuality = FilterQuality.high);
    canvas.restore();
  }

  // Fallback to custom painting if PNG is not available
  void _drawCustomEffect(Canvas canvas, Face face, double scaleX, double scaleY, Size size) {
    switch (effectId) {
      case 'dog':
        _drawDogEffect(canvas, face, scaleX, scaleY);
        break;
      case 'cat':
        _drawCatEffect(canvas, face, scaleX, scaleY);
        break;
      case 'rabbit':
        _drawRabbitEffect(canvas, face, scaleX, scaleY);
        break;
      case 'lion':
        _drawLionEffect(canvas, face, scaleX, scaleY);
        break;
      case 'panda':
        _drawPandaEffect(canvas, face, scaleX, scaleY);
        break;
      case 'cool_shades':
        _drawCoolShadesEffect(canvas, face, scaleX, scaleY);
        break;
      case 'flower_crown':
        _drawFlowerCrownEffect(canvas, face, scaleX, scaleY);
        break;
      case 'butterfly':
        _drawButterflyFallback(canvas, face, scaleX, scaleY);
        break;
      case 'devil_horns':
        _drawDevilHornsEffect(canvas, face, scaleX, scaleY);
        break;
      case 'fire_eyes':
        _drawFireEyesEffect(canvas, face, scaleX, scaleY);
        break;
      case 'lipstick':
        _drawLipstickFallback(canvas, face, scaleX, scaleY);
        break;
      case 'neon_crown':
        _drawNeonCrownEffect(canvas, face, scaleX, scaleY);
        break;
      case 'star_freckles':
        _drawStarFrecklesEffect(canvas, face, scaleX, scaleY);
        break;
      default:
        break;
    }
  }

  // Helper method to convert Point to Offset
  Offset _pointToOffset(Point<int> point, double scaleX, double scaleY) {
    return Offset(point.x.toDouble() * scaleX, point.y.toDouble() * scaleY);
  }

  // ===== FALLBACK CUSTOM DRAWING METHODS =====

  void _drawDogEffect(Canvas canvas, Face face, double scaleX, double scaleY) {
    final rect = face.boundingBox;
    final earPaint = Paint()
      ..color = const Color(0xFF8B4513)
      ..style = PaintingStyle.fill;

    // Left ear
    final leftEarPath = Path();
    leftEarPath.moveTo(rect.left * scaleX - 30, rect.top * scaleY);
    leftEarPath.quadraticBezierTo(
      rect.left * scaleX - 50,
      rect.top * scaleY + 50,
      rect.left * scaleX - 20,
      rect.top * scaleY + 100,
    );
    leftEarPath.lineTo(rect.left * scaleX, rect.top * scaleY + 80);
    leftEarPath.close();
    canvas.drawPath(leftEarPath, earPaint);

    // Right ear
    final rightEarPath = Path();
    rightEarPath.moveTo(rect.right * scaleX + 30, rect.top * scaleY);
    rightEarPath.quadraticBezierTo(
      rect.right * scaleX + 50,
      rect.top * scaleY + 50,
      rect.right * scaleX + 20,
      rect.top * scaleY + 100,
    );
    rightEarPath.lineTo(rect.right * scaleX, rect.top * scaleY + 80);
    rightEarPath.close();
    canvas.drawPath(rightEarPath, earPaint);

    // Nose
    final noseBase = face.landmarks[FaceLandmarkType.noseBase];
    if (noseBase != null) {
      final nosePos = _pointToOffset(noseBase.position, scaleX, scaleY);
      final nosePaint = Paint()..color = Colors.black;
      canvas.drawCircle(nosePos, 15, nosePaint);
    }
  }

  void _drawCatEffect(Canvas canvas, Face face, double scaleX, double scaleY) {
    final rect = face.boundingBox;
    final earPaint = Paint()
      ..color = const Color(0xFFFFA07A)
      ..style = PaintingStyle.fill;

    final earOutlinePaint = Paint()
      ..color = const Color(0xFFFF8C69)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Left ear (triangle)
    final leftEarPath = Path();
    leftEarPath.moveTo(rect.left * scaleX + 20, rect.top * scaleY);
    leftEarPath.lineTo(rect.left * scaleX - 20, rect.top * scaleY - 60);
    leftEarPath.lineTo(rect.left * scaleX + 40, rect.top * scaleY - 20);
    leftEarPath.close();
    canvas.drawPath(leftEarPath, earPaint);
    canvas.drawPath(leftEarPath, earOutlinePaint);

    // Right ear
    final rightEarPath = Path();
    rightEarPath.moveTo(rect.right * scaleX - 20, rect.top * scaleY);
    rightEarPath.lineTo(rect.right * scaleX + 20, rect.top * scaleY - 60);
    rightEarPath.lineTo(rect.right * scaleX - 40, rect.top * scaleY - 20);
    rightEarPath.close();
    canvas.drawPath(rightEarPath, earPaint);
    canvas.drawPath(rightEarPath, earOutlinePaint);

    // Whiskers
    final whiskerPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final noseTip = Offset(rect.center.dx * scaleX, rect.center.dy * scaleY);

    for (int i = -1; i <= 1; i++) {
      canvas.drawLine(
        noseTip,
        Offset(rect.left * scaleX - 40, noseTip.dy + i * 15),
        whiskerPaint,
      );
      canvas.drawLine(
        noseTip,
        Offset(rect.right * scaleX + 40, noseTip.dy + i * 15),
        whiskerPaint,
      );
    }
  }

  void _drawRabbitEffect(Canvas canvas, Face face, double scaleX, double scaleY) {
    final rect = face.boundingBox;
    final earPaint = Paint()
      ..color = const Color(0xFFFFB6C1)
      ..style = PaintingStyle.fill;

    // Long rabbit ears
    final leftEarPath = Path();
    leftEarPath.moveTo(rect.left * scaleX + 30, rect.top * scaleY);
    leftEarPath.quadraticBezierTo(
      rect.left * scaleX - 10,
      rect.top * scaleY - 80,
      rect.left * scaleX + 10,
      rect.top * scaleY - 120,
    );
    leftEarPath.quadraticBezierTo(
      rect.left * scaleX + 30,
      rect.top * scaleY - 100,
      rect.left * scaleX + 50,
      rect.top * scaleY - 10,
    );
    leftEarPath.close();
    canvas.drawPath(leftEarPath, earPaint);

    final rightEarPath = Path();
    rightEarPath.moveTo(rect.right * scaleX - 30, rect.top * scaleY);
    rightEarPath.quadraticBezierTo(
      rect.right * scaleX + 10,
      rect.top * scaleY - 80,
      rect.right * scaleX - 10,
      rect.top * scaleY - 120,
    );
    rightEarPath.quadraticBezierTo(
      rect.right * scaleX - 30,
      rect.top * scaleY - 100,
      rect.right * scaleX - 50,
      rect.top * scaleY - 10,
    );
    rightEarPath.close();
    canvas.drawPath(rightEarPath, earPaint);
  }

  void _drawLionEffect(Canvas canvas, Face face, double scaleX, double scaleY) {
    final rect = face.boundingBox;
    final center = Offset(rect.center.dx * scaleX, rect.center.dy * scaleY);
    final manePaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final radius = rect.width * scaleX * 0.8;
    for (int i = 0; i < 16; i++) {
      final angle = (i * pi * 2) / 16;
      final x = center.dx + cos(angle) * radius;
      final y = center.dy + sin(angle) * radius;
      canvas.drawCircle(Offset(x, y), 30, manePaint);
    }
  }

  void _drawPandaEffect(Canvas canvas, Face face, double scaleX, double scaleY) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    final rect = face.boundingBox;

    final blackPaint = Paint()..color = Colors.black;

    if (leftEye != null && rightEye != null) {
      final leftPos = _pointToOffset(leftEye.position, scaleX, scaleY);
      final rightPos = _pointToOffset(rightEye.position, scaleX, scaleY);
      canvas.drawCircle(leftPos, 35, blackPaint);
      canvas.drawCircle(rightPos, 35, blackPaint);
    }

    canvas.drawCircle(
      Offset(rect.left * scaleX + 20, rect.top * scaleY - 20),
      30,
      blackPaint,
    );
    canvas.drawCircle(
      Offset(rect.right * scaleX - 20, rect.top * scaleY - 20),
      30,
      blackPaint,
    );
  }

  void _drawCoolShadesEffect(Canvas canvas, Face face, double scaleX, double scaleY) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];

    if (leftEye != null && rightEye != null) {
      final shadesPaint = Paint()
        ..color = Colors.black.withOpacity(0.8)
        ..style = PaintingStyle.fill;

      final framePaint = Paint()
        ..color = Colors.grey[800]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      final leftPos = _pointToOffset(leftEye.position, scaleX, scaleY);
      final rightPos = _pointToOffset(rightEye.position, scaleX, scaleY);

      final leftLensRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: leftPos, width: 70, height: 50),
        const Radius.circular(5),
      );
      canvas.drawRRect(leftLensRect, shadesPaint);
      canvas.drawRRect(leftLensRect, framePaint);

      final rightLensRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: rightPos, width: 70, height: 50),
        const Radius.circular(5),
      );
      canvas.drawRRect(rightLensRect, shadesPaint);
      canvas.drawRRect(rightLensRect, framePaint);

      canvas.drawLine(
        Offset(leftPos.dx + 35, leftPos.dy),
        Offset(rightPos.dx - 35, rightPos.dy),
        framePaint,
      );
    }
  }

  void _drawFlowerCrownEffect(Canvas canvas, Face face, double scaleX, double scaleY) {
    final rect = face.boundingBox;
    final topCenter = Offset(rect.center.dx * scaleX, rect.top * scaleY - 40);

    final petalPaint = Paint()
      ..color = const Color(0xFFFF69B4)
      ..style = PaintingStyle.fill;

    final centerPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 5; i++) {
      final x = rect.left * scaleX + (rect.width * scaleX * i / 4);
      final y = topCenter.dy + sin(i * 0.5) * 10;

      for (int j = 0; j < 6; j++) {
        final angle = (j * pi * 2) / 6;
        final petalX = x + cos(angle) * 15;
        final petalY = y + sin(angle) * 15;
        canvas.drawCircle(Offset(petalX, petalY), 8, petalPaint);
      }

      canvas.drawCircle(Offset(x, y), 6, centerPaint);
    }
  }

  void _drawButterflyFallback(Canvas canvas, Face face, double scaleX, double scaleY) {
    final noseBase = face.landmarks[FaceLandmarkType.noseBase];
    if (noseBase == null) return;

    final wingPaint = Paint()
      ..color = const Color(0xFFFF69B4).withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final bodyPaint = Paint()..color = Colors.black;

    final nosePos = _pointToOffset(noseBase.position, scaleX, scaleY);
    final center = Offset(nosePos.dx, nosePos.dy - 30);

    final leftWing = Path();
    leftWing.moveTo(center.dx, center.dy);
    leftWing.quadraticBezierTo(center.dx - 30, center.dy - 20, center.dx - 40, center.dy);
    leftWing.quadraticBezierTo(center.dx - 30, center.dy + 20, center.dx, center.dy);
    canvas.drawPath(leftWing, wingPaint);

    final rightWing = Path();
    rightWing.moveTo(center.dx, center.dy);
    rightWing.quadraticBezierTo(center.dx + 30, center.dy - 20, center.dx + 40, center.dy);
    rightWing.quadraticBezierTo(center.dx + 30, center.dy + 20, center.dx, center.dy);
    canvas.drawPath(rightWing, wingPaint);

    canvas.drawCircle(center, 3, bodyPaint);
  }

  void _drawDevilHornsEffect(Canvas canvas, Face face, double scaleX, double scaleY) {
    final rect = face.boundingBox;
    final hornPaint = Paint()
      ..color = const Color(0xFFDC143C)
      ..style = PaintingStyle.fill;

    final leftHornPath = Path();
    leftHornPath.moveTo(rect.left * scaleX + 30, rect.top * scaleY - 10);
    leftHornPath.lineTo(rect.left * scaleX + 10, rect.top * scaleY - 50);
    leftHornPath.lineTo(rect.left * scaleX + 40, rect.top * scaleY - 30);
    leftHornPath.close();
    canvas.drawPath(leftHornPath, hornPaint);

    final rightHornPath = Path();
    rightHornPath.moveTo(rect.right * scaleX - 30, rect.top * scaleY - 10);
    rightHornPath.lineTo(rect.right * scaleX - 10, rect.top * scaleY - 50);
    rightHornPath.lineTo(rect.right * scaleX - 40, rect.top * scaleY - 30);
    rightHornPath.close();
    canvas.drawPath(rightHornPath, hornPaint);
  }

  void _drawFireEyesEffect(Canvas canvas, Face face, double scaleX, double scaleY) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];

    if (leftEye != null && rightEye != null) {
      final leftPos = _pointToOffset(leftEye.position, scaleX, scaleY);
      final rightPos = _pointToOffset(rightEye.position, scaleX, scaleY);

      final firePaint = Paint()
        ..shader = ui.Gradient.radial(
          leftPos,
          30,
          [Colors.yellow, Colors.orange, Colors.red, Colors.transparent],
          [0.0, 0.3, 0.6, 1.0],
        )
        ..style = PaintingStyle.fill;

      for (int i = 0; i < 5; i++) {
        final flameHeight = 20 + Random(i).nextDouble() * 20;
        final flamePath = Path();
        flamePath.moveTo(leftPos.dx - 15 + i * 7, leftPos.dy);
        flamePath.quadraticBezierTo(
          leftPos.dx - 12 + i * 7,
          leftPos.dy - flameHeight,
          leftPos.dx - 10 + i * 7,
          leftPos.dy,
        );
        canvas.drawPath(flamePath, firePaint);
      }

      for (int i = 0; i < 5; i++) {
        final flameHeight = 20 + Random(i).nextDouble() * 20;
        final flamePath = Path();
        flamePath.moveTo(rightPos.dx - 15 + i * 7, rightPos.dy);
        flamePath.quadraticBezierTo(
          rightPos.dx - 12 + i * 7,
          rightPos.dy - flameHeight,
          rightPos.dx - 10 + i * 7,
          rightPos.dy,
        );
        canvas.drawPath(flamePath, firePaint);
      }
    }
  }

  void _drawLipstickFallback(Canvas canvas, Face face, double scaleX, double scaleY) {
    final bottomMouth = face.landmarks[FaceLandmarkType.bottomMouth];
    if (bottomMouth == null) return;

    final lipPaint = Paint()
      ..color = const Color(0xFFFF0000)
      ..style = PaintingStyle.fill;

    final mouthPos = _pointToOffset(bottomMouth.position, scaleX, scaleY);
    final lipPath = Path();
    lipPath.addOval(Rect.fromCenter(
      center: mouthPos,
      width: 60,
      height: 20,
    ));
    canvas.drawPath(lipPath, lipPaint);
  }

  void _drawNeonCrownEffect(Canvas canvas, Face face, double scaleX, double scaleY) {
    final rect = face.boundingBox;
    final time = DateTime.now().millisecondsSinceEpoch / 500;

    final neonPaint = Paint()
      ..color = HSVColor.fromAHSV(1, (time % 360), 1, 1).toColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final crownPath = Path();
    final topCenter = Offset(rect.center.dx * scaleX, rect.top * scaleY - 60);

    for (int i = 0; i < 7; i++) {
      final x = rect.left * scaleX + (rect.width * scaleX * i / 6);
      final y = i % 2 == 0 ? topCenter.dy : topCenter.dy + 20;
      if (i == 0) {
        crownPath.moveTo(x, y);
      } else {
        crownPath.lineTo(x, y);
      }
    }

    canvas.drawPath(crownPath, neonPaint);
  }

  void _drawStarFrecklesEffect(Canvas canvas, Face face, double scaleX, double scaleY) {
    final rect = face.boundingBox;
    final random = Random(42);

    final starPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 10; i++) {
      final x = rect.left * scaleX + random.nextDouble() * rect.width * scaleX;
      final y = rect.center.dy * scaleY + random.nextDouble() * rect.height * 0.3 * scaleY;
      _drawStar(canvas, Offset(x, y), 5, starPaint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 4 * pi) / 5 - pi / 2;
      final x = center.dx + cos(angle) * size;
      final y = center.dy + sin(angle) * size;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(FaceEffectsPainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.effectId != effectId ||
        oldDelegate.effectImage != effectImage;
  }
}