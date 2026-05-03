import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

// ─────────────────────────────────────────────────────────────
// CONFIG — change to match your app
// ─────────────────────────────────────────────────────────────
const String _kDeepLinkBase = 'myvibeflick://user/';

// ─────────────────────────────────────────────────────────────
// COLORS
// ─────────────────────────────────────────────────────────────
class _C {
  static const bg          = Color(0xFF0E0E0E);
  static const surface     = Color(0xFF1A1A1A);
  static const surfaceHigh = Color(0xFF242424);
  static const border      = Color(0xFF2C2C2C);
  static const accent      = Color(0xFFFF3B5C);
  static const accentSoft  = Color(0x33FF3B5C);
  static const textPri     = Color(0xFFFFFFFF);
  static const textSec     = Color(0xFF888888);
  static const textHint    = Color(0xFF444444);
  static const handle      = Color(0xFF3A3A3A);
  static const qrFg        = Color(0xFFEEEEEE);
  static const qrBg        = Color(0xFF111111);
}

// ─────────────────────────────────────────────────────────────
// 1. QR BOTTOM SHEET
// ─────────────────────────────────────────────────────────────
class QrBottomSheet extends StatefulWidget {
  final String uid;
  final String displayName;
  final String? avatarUrl;

  const QrBottomSheet({
    super.key,
    required this.uid,
    required this.displayName,
    this.avatarUrl,
  });

  @override
  State<QrBottomSheet> createState() => _QrBottomSheetState();
}

class _QrBottomSheetState extends State<QrBottomSheet>
    with SingleTickerProviderStateMixin {
  final ScreenshotController _sc = ScreenshotController();
  bool _isSaving = false;
  AnimationController? _animCtrl;
  Animation<double>?   _fadeAnim;
  Animation<Offset>?   _slideAnim;

  String get _qrData => '$_kDeepLinkBase${widget.uid}';

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(
        parent: _animCtrl!, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animCtrl!, curve: Curves.easeOutCubic));
    _animCtrl!.forward();
  }

  @override
  void dispose() {
    _animCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade  = _fadeAnim  ?? const AlwaysStoppedAnimation(1.0);
    final slide = _slideAnim ?? const AlwaysStoppedAnimation(Offset.zero);

    return Container(
      decoration: const BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top:   BorderSide(color: _C.border, width: 1),
          left:  BorderSide(color: _C.border, width: 1),
          right: BorderSide(color: _C.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 3,
                      decoration: BoxDecoration(
                        color: _C.handle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  Row(
                    children: [
                      const Text(
                        'My QR Code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _C.textPri,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _C.accentSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'SCAN TO FOLLOW',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _C.accent,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Screenshot(
                    controller: _sc,
                    child: _QrCard(
                      qrData:      _qrData,
                      displayName: widget.displayName,
                      avatarUrl:   widget.avatarUrl,
                    ),
                  ),
                  const SizedBox(height: 28),

                  Container(height: 1, color: _C.border),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(child: _ActionBtn(
                        icon: Icons.download_rounded,
                        label: 'Save',
                        isLoading: _isSaving,
                        onTap: _saveToGallery,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _ActionBtn(
                        icon: Icons.share_rounded,
                        label: 'Share',
                        onTap: _shareQr,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _ActionBtn(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Scan',
                        onTap: _openScanner,
                        isAccent: true,
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveToGallery() async {
    setState(() => _isSaving = true);
    try {
      final bytes = await _sc.capture(pixelRatio: 3.0);
      if (bytes == null) throw Exception('Capture failed');
      await Gal.putImageBytes(bytes);
      if (mounted) _snack('Saved to gallery', ok: true);
    } catch (e) {
      if (mounted) _snack('Error: $e', ok: false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareQr() async {
    try {
      final bytes = await _sc.capture(pixelRatio: 3.0);
      if (bytes == null) throw Exception('Capture failed');
      final tmp  = await getTemporaryDirectory();
      final file = File('${tmp.path}/qr_share.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${widget.displayName} — Scan to view profile',
      );
    } catch (e) {
      if (mounted) _snack('Share failed: $e', ok: false);
    }
  }

  Future<void> _openScanner() async {
    final status = await Permission.camera.status;
    if (status.isDenied) {
      final result = await Permission.camera.request();
      if (!result.isGranted) {
        if (mounted) _snack('Camera permission is required.', ok: false);
        return;
      }
    }
    if (status.isPermanentlyDenied) {
      if (mounted) {
        _snack('Enable camera access in Settings.', ok: false);
        await openAppSettings();
      }
      return;
    }
    if (mounted) {
      Navigator.pop(context);
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const QrScannerPage()));
    }
  }

  void _snack(String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500))),
      ]),
      behavior: SnackBarBehavior.floating,
      backgroundColor:
      ok ? const Color(0xFF1E3A2F) : const Color(0xFF3A1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }
}

// ─────────────────────────────────────────────────────────────
// 2. QR CARD
// ─────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────
// 2. QR CARD  (StatefulWidget — preloads logo, shows shimmer)
// ─────────────────────────────────────────────────────────────
class _QrCard extends StatefulWidget {
  final String qrData;
  final String displayName;
  final String? avatarUrl;

  const _QrCard({
    required this.qrData,
    required this.displayName,
    this.avatarUrl,
  });

  @override
  State<_QrCard> createState() => _QrCardState();
}

class _QrCardState extends State<_QrCard> {
  bool _logoReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preloadLogo();
  }

  Future<void> _preloadLogo() async {
    try {
      await precacheImage(
          const AssetImage('assets/images/app_logo.png'), context);
    } catch (_) {
      // logo missing — QR still renders
    }
    if (mounted) setState(() => _logoReady = true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.qrBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border, width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6),
              blurRadius: 32, offset: const Offset(0, 12)),
          BoxShadow(color: _C.accent.withOpacity(0.07),
              blurRadius: 40, spreadRadius: 4),
        ],
      ),
      child: Column(children: [
        Container(
          height: 3,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFFFF3B5C), Color(0xFFFF6B35)]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(children: [
            Row(children: [
              _avatar(),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.displayName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: _C.textPri, letterSpacing: -0.3),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  const Text('Scan to view profile',
                      style: TextStyle(fontSize: 12, color: _C.textSec)),
                ],
              )),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                    color: _C.accentSoft,
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.qr_code_2_rounded,
                    color: _C.accent, size: 18),
              ),
            ]),
            const SizedBox(height: 18),
            Container(height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent, _C.border, Colors.transparent,
                ]),
              ),
            ),
            const SizedBox(height: 18),

            // QR or shimmer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _C.border.withOpacity(0.5), width: 1),
              ),
              child: _logoReady
                  ? QrImageView(
                data: widget.qrData,
                version: QrVersions.auto,
                size: 190,
                backgroundColor: const Color(0xFF111111),
                eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square, color: _C.qrFg),
                dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: _C.qrFg),
                embeddedImage:
                const AssetImage('assets/images/app_logo.png'),
                embeddedImageStyle:
                const QrEmbeddedImageStyle(size: Size(44, 44)),
              )
                  : const _QrShimmer(),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _C.surfaceHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.border, width: 1),
              ),
              child: Text(
                widget.qrData.length > 32
                    ? '${widget.qrData.substring(0, 32)}…'
                    : widget.qrData,
                style: const TextStyle(
                    fontSize: 10, color: _C.textHint,
                    fontFamily: 'monospace', letterSpacing: 0.4),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _avatar() {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _C.accent, width: 1.5),
        boxShadow: [BoxShadow(
            color: _C.accent.withOpacity(0.25), blurRadius: 12, spreadRadius: 1)],
      ),
      child: ClipOval(
        child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
            ? Image.network(widget.avatarUrl!, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initials())
            : _initials(),
      ),
    );
  }

  Widget _initials() {
    final l = widget.displayName.isNotEmpty
        ? widget.displayName.trim().split(' ').map((w) => w[0]).take(2).join()
        : '?';
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Center(child: Text(l.toUpperCase(),
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: _C.accent))),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// QR SHIMMER  — animated loading placeholder
// ─────────────────────────────────────────────────────────────
class _QrShimmer extends StatefulWidget {
  const _QrShimmer();
  @override
  State<_QrShimmer> createState() => _QrShimmerState();
}

class _QrShimmerState extends State<_QrShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190, height: 190,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0.25 + (_anim.value * 0.55),
              child: const Icon(Icons.qr_code_2_rounded,
                  color: _C.accent, size: 60),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final v = ((_anim.value + i / 3) % 1.0);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: _C.accent.withOpacity(0.25 + v * 0.75),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            const Text('Generating…',
                style: TextStyle(
                    fontSize: 11, color: _C.textSec, letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isAccent;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.isAccent  = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isAccent ? _C.accent : _C.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: isAccent ? null : Border.all(color: _C.border, width: 1),
          boxShadow: isAccent
              ? [BoxShadow(color: _C.accent.withOpacity(0.3),
              blurRadius: 16, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          isLoading
              ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _C.textPri))
              : Icon(icon,
              color: isAccent ? Colors.white : _C.textSec, size: 22),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isAccent ? Colors.white : _C.textSec,
                  letterSpacing: 0.2)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 4. QR SCANNER PAGE
// ─────────────────────────────────────────────────────────────
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});
  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _isProcessing   = false;
  bool _permDenied     = false;
  AnimationController? _lineCtrl;

  @override
  void initState() {
    super.initState();
    _lineCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (status.isDenied) {
      final r = await Permission.camera.request();
      if (!r.isGranted && mounted) setState(() => _permDenied = true);
    } else if (status.isPermanentlyDenied && mounted) {
      setState(() => _permDenied = true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _lineCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permDenied) return _buildPermDenied();

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 20),
          ),
        ),
        title: const Text('Scan QR Code',
            style: TextStyle(color: Colors.white,
                fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          _appBtn(Icons.flash_on_rounded, () => _ctrl.toggleTorch()),
          _appBtn(Icons.flip_camera_ios_rounded, () => _ctrl.switchCamera(),
              mr: 16),
        ],
      ),
      body: Stack(children: [
        MobileScanner(controller: _ctrl, onDetect: _onDetect),
        if (_lineCtrl != null) _ScannerOverlay(lineCtrl: _lineCtrl!),
        Positioned(
          bottom: 48, left: 24, right: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_rounded, color: _C.accent, size: 18),
                SizedBox(width: 10),
                Text('Point camera at a QR code',
                    style: TextStyle(color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _appBtn(IconData icon, VoidCallback onTap, {double mr = 8}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(right: mr),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildPermDenied() {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: _C.surfaceHigh,
                border: Border.all(color: _C.border)),
            child: const Icon(Icons.camera_alt_rounded,
                color: _C.textSec, size: 36),
          ),
          const SizedBox(height: 24),
          const Text('Camera Access Required',
              style: TextStyle(color: _C.textPri,
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text(
            'Please enable camera access in Settings to scan QR codes.',
            style: TextStyle(color: _C.textSec, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: openAppSettings,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              decoration: BoxDecoration(
                color: _C.accent,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: _C.accent.withOpacity(0.3),
                    blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: const Text('Open Settings',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text('Go Back',
                style: TextStyle(color: _C.textSec, fontSize: 14)),
          ),
        ]),
      )),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue ?? '';
    if (raw.isEmpty) return;

    // Validate — must be our deep link
    if (!raw.startsWith(_kDeepLinkBase)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Text('This QR code is not from this app.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ]),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF3A2A1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ));
      return;
    }

    final uid = raw.replaceFirst(_kDeepLinkBase, '').trim();
    if (uid.isEmpty) return;

    setState(() => _isProcessing = true);
    _ctrl.stop();
    HapticFeedback.mediumImpact(); // ← vibrate on successful scan

    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => OtherUserProfilePage(uid: uid)));
  }
}

// ─────────────────────────────────────────────────────────────
// 5. SCANNER OVERLAY
// ─────────────────────────────────────────────────────────────
class _ScannerOverlay extends StatelessWidget {
  final AnimationController lineCtrl;
  const _ScannerOverlay({required this.lineCtrl});

  @override
  Widget build(BuildContext context) {
    final s    = MediaQuery.of(context).size;
    const cut  = 260.0;
    final top  = (s.height - cut) / 2 - 30;
    final left = (s.width  - cut) / 2;

    return Stack(children: [
      CustomPaint(
        size: Size(s.width, s.height),
        painter: _OverlayPainter(
            cutoutRect: Rect.fromLTWH(left, top, cut, cut)),
      ),
      Positioned(
        left: left + 8, top: top + 8,
        width: cut - 16, height: cut - 16,
        child: AnimatedBuilder(
          animation: lineCtrl,
          builder: (_, __) => Stack(children: [
            Positioned(
              top: (cut - 16) * lineCtrl.value,
              left: 0, right: 0,
              child: Container(height: 2,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent, _C.accent, Colors.transparent,
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
      _corner(left - 1,        top - 1,        true,  true),
      _corner(left + cut - 23, top - 1,        false, true),
      _corner(left - 1,        top + cut - 23, true,  false),
      _corner(left + cut - 23, top + cut - 23, false, false),
    ]);
  }

  Widget _corner(double l, double t, bool isLeft, bool isTop) =>
      Positioned(
        left: l, top: t,
        child: SizedBox(width: 24, height: 24,
            child: CustomPaint(
                painter: _CornerPainter(isLeft: isLeft, isTop: isTop))),
      );
}

class _OverlayPainter extends CustomPainter {
  final Rect cutoutRect;
  _OverlayPainter({required this.cutoutRect});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.72);
    final path  = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(cutoutRect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(_OverlayPainter old) => old.cutoutRect != cutoutRect;
}

class _CornerPainter extends CustomPainter {
  final bool isLeft, isTop;
  _CornerPainter({required this.isLeft, required this.isTop});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color       = _C.accent
      ..strokeWidth = 3
      ..strokeCap   = StrokeCap.round
      ..style       = PaintingStyle.stroke;
    final x  = isLeft ? 0.0 : size.width;
    final y  = isTop  ? 0.0 : size.height;
    final dx = isLeft ? size.width  : -size.width;
    final dy = isTop  ? size.height : -size.height;
    canvas.drawLine(Offset(x, y), Offset(x + dx, y), p);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy), p);
  }
  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

// ─────────────────────────────────────────────────────────────
// 6. OTHER USER PROFILE PAGE (placeholder)
//    TODO: Replace with your real OtherUserProfile widget
// ─────────────────────────────────────────────────────────────
class OtherUserProfilePage extends StatelessWidget {
  final String uid;
  const OtherUserProfilePage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        foregroundColor: _C.textPri,
        title: const Text('Profile',
            style: TextStyle(color: _C.textPri, fontWeight: FontWeight.w600)),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _C.border),
        ),
      ),
      body: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.surfaceHigh,
              border: Border.all(color: _C.border, width: 1),
            ),
            child: const Icon(Icons.person_rounded,
                size: 40, color: _C.textSec),
          ),
          const SizedBox(height: 20),
          const Text('Loading profile…',
              style: TextStyle(color: _C.textSec,
                  fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 13),
              decoration: BoxDecoration(
                color: _C.accent,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: _C.accent.withOpacity(0.3),
                    blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: const Text('Follow',
                  style: TextStyle(color: Colors.white,
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      )),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// pubspec.yaml — add:
//   permission_handler: ^11.3.1
//
// assets/images/app_logo.png  ← your app logo (white/transparent bg)
//
// AndroidManifest.xml:
//   <uses-permission android:name="android.permission.CAMERA"/>
//   <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
//
// Info.plist:
//   NSCameraUsageDescription → "Required to scan QR codes"
//   NSPhotoLibraryAddUsageDescription → "Required to save QR codes"