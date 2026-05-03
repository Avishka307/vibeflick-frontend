import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'location_cache_service.dart'; // ← path adjust කරන්න
// ─────────────────────────────────────────────────────────────────────────────
// 📍 CreateTextPostScreen — Glassmorphism Vibe Post Creator
//    • Real GPS location  (geolocator + geocoding)
//    • POST → /api/text-posts/create  (Firestore 'text_posts' collection)
//    • Cloudinary ❌  — text + gradient + location only
// ─────────────────────────────────────────────────────────────────────────────
class CreateTextPostScreen extends StatefulWidget {
  const CreateTextPostScreen({super.key});

  @override
  State<CreateTextPostScreen> createState() => _CreateTextPostScreenState();
}

class _CreateTextPostScreenState extends State<CreateTextPostScreen> {

  // ── State ───────────────────────────────────────────────────────────────────
  String postContent = '';
  String privacyMode = 'Nearby Only';
  bool isAnonymous = false;
  String _countryName = '';
  String _countryCode = '';
  int selectedGradient = 0;

  bool _locationLoading = false;
  bool _locationGranted = false;
  double? _latitude;
  double? _longitude;
  String _cityName = 'Locating…';

  bool _isPosting = false;

  // ── Gradients ───────────────────────────────────────────────────────────────
  static const List<LinearGradient> gradients = [
    // ✅ දැනටමත් තියෙන 6 (වෙනස් කළේ නැහැ)
    LinearGradient(
        colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF2d1b69), Color(0xFF11998e)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1a1a2e), Color(0xFF6b2d5e)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF0f2027), Color(0xFF203a43), Color(0xFF2c5364)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF1a0a00), Color(0xFF5c3a00), Color(0xFF8b5e00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),

    // ✅ තව 50 අලුත් gradients (ලස්සන dark vibes)
    LinearGradient(colors: [Color(0xFF000428), Color(0xFF004e92)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF360033), Color(0xFF0b8793)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1f4037), Color(0xFF99f2c8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF3a1c71), Color(0xFFd76d77), Color(0xFFffaf7b)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0052d4), Color(0xFF4364f7), Color(0xFF6fb1fc)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF16222a), Color(0xFF3a6073)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF373b44), Color(0xFF4286f4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0b0c10), Color(0xFF1f2833), Color(0xFF45a29e)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF2c003e), Color(0xFF8b00ff)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF002f4b), Color(0xFFdc4225)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1c1c2e), Color(0xFF2e4057), Color(0xFF048a81)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0d0d0d), Color(0xFF1a1a2e), Color(0xFFe94560)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1b2631), Color(0xFF2c3e50)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF4a0072), Color(0xFF9c27b0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF003300), Color(0xFF006600), Color(0xFF00cc44)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1a0533), Color(0xFF4a0080), Color(0xFF9900ff)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0a0a0a), Color(0xFF1a1a1a), Color(0xFF2d6a4f)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF091833), Color(0xFF1a3a6b), Color(0xFF2563eb)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1c0221), Color(0xFF6a0572), Color(0xFFab83a1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0d1117), Color(0xFF161b22), Color(0xFF58a6ff)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF3d0000), Color(0xFF8b0000)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF020024), Color(0xFF090979), Color(0xFF00d4ff)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0a3d62), Color(0xFF1e3799)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF192a56), Color(0xFF273c75)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF130f40), Color(0xFF30305e), Color(0xFF7f00ff)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1a1a1a), Color(0xFF2d2d2d), Color(0xFF00b4d8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF2b5876), Color(0xFF4e4376)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0c0c0c), Color(0xFF1f1c2c), Color(0xFF928dab)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF004953), Color(0xFF007965)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1c2833), Color(0xFF2e86c1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF3b1f2b), Color(0xFF7b2d8b), Color(0xFFaa076b)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0f2041), Color(0xFF1557ea)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1a0a2e), Color(0xFF6c3483)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF00111c), Color(0xFF003b5c), Color(0xFF006994)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1a1a2e), Color(0xFF533483)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0f0f1a), Color(0xFF1a1a35), Color(0xFF00c9ff)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF001a00), Color(0xFF003300), Color(0xFF00ff88)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0d0221), Color(0xFF3a0ca3)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF140152), Color(0xFF22007c), Color(0xFF0d00a4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0b132b), Color(0xFF1c2541), Color(0xFF3a506b)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF2c003e), Color(0xFF560bad)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF010b13), Color(0xFF02233a), Color(0xFF0077b6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF10002b), Color(0xFF240046), Color(0xFF7b2d8b)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF023e8a), Color(0xFF0077b6), Color(0xFF00b4d8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1b0000), Color(0xFF3d0000), Color(0xFFb00020)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF003049), Color(0xFF023e7d)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0e0e0e), Color(0xFF1c1c1c), Color(0xFF2e4057)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF2d132c), Color(0xFF810034)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF00005c), Color(0xFF0000ab), Color(0xFF4040ff)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0a001a), Color(0xFF1a0040), Color(0xFF6600cc)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF001219), Color(0xFF005f73), Color(0xFF0a9396)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1c0a00), Color(0xFF4d2600), Color(0xFF7a3b00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  ];

  static const List<Color> dotColors = [
    // ✅ දැනටමත් තියෙන 6 (වෙනස් කළේ නැහැ)
    Color(0xFF0f3460), Color(0xFF11998e), Color(0xFF302b63),
    Color(0xFF6b2d5e), Color(0xFF2c5364), Color(0xFF8b5e00),

    // ✅ තව 50 අලුත් colors (gradients වලට match වෙන විදියට)
    Color(0xFF004e92), Color(0xFF0b8793), Color(0xFF99f2c8), Color(0xFFffaf7b), Color(0xFF6fb1fc),
    Color(0xFF3a6073), Color(0xFF4286f4), Color(0xFF45a29e), Color(0xFF8b00ff), Color(0xFFdc4225),
    Color(0xFF048a81), Color(0xFFe94560), Color(0xFF2c3e50), Color(0xFF9c27b0), Color(0xFF00cc44),
    Color(0xFF9900ff), Color(0xFF2d6a4f), Color(0xFF2563eb), Color(0xFFab83a1), Color(0xFF58a6ff),
    Color(0xFF8b0000), Color(0xFF00d4ff), Color(0xFF1e3799), Color(0xFF273c75), Color(0xFF7f00ff),
    Color(0xFF00b4d8), Color(0xFF4e4376), Color(0xFF928dab), Color(0xFF007965), Color(0xFF2e86c1),
    Color(0xFFaa076b), Color(0xFF1557ea), Color(0xFF6c3483), Color(0xFF006994), Color(0xFF533483),
    Color(0xFF00c9ff), Color(0xFF00ff88), Color(0xFF3a0ca3), Color(0xFF0d00a4), Color(0xFF3a506b),
    Color(0xFF560bad), Color(0xFF0077b6), Color(0xFF7b2d8b), Color(0xFF00b4d8), Color(0xFFb00020),
    Color(0xFF023e7d), Color(0xFF2e4057), Color(0xFF810034), Color(0xFF4040ff), Color(0xFF6600cc),
  ];

  static const int _maxChars = 500;


  static const String _baseUrl = 'https://avishka-tiktok-api.zeabur.app';

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _checkAndFetchLocation();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 📍 LOCATION METHODS
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _checkAndFetchLocation() async {
    setState(() => _locationLoading = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // ← Location services off නම් settings open කරන්න
        setState(() {
          _cityName = 'Location services off';
          _locationLoading = false;
        });
        await Geolocator.openLocationSettings(); // ← මේක add කරන්න
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationGranted = false;
          _cityName = 'Location denied';
          _locationLoading = false;
        });
        await Geolocator.openAppSettings(); // ← permanently denied නම්
        return;
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _locationGranted = false;
          _cityName = 'Location denied';
          _locationLoading = false;
        });
        return;
      }

      setState(() => _locationGranted = true);
      await _fetchCurrentLocation();

    } catch (e) {
      debugPrint('Location check error: $e');
      setState(() {
        _cityName = 'Location error';
        _locationLoading = false;
      });
    }
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _locationLoading = true;
      _cityName = 'Locating…';
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;
      // Reverse geocode → city name
      final placemarks = await placemarkFromCoordinates(_latitude!, _longitude!);
      String city = 'Unknown';
      String countryName = '';
      String countryCode = '';
      // Reverse geocode → city name
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        city = p.locality?.isNotEmpty == true
            ? p.locality!
            : (p.subAdministrativeArea?.isNotEmpty == true
            ? p.subAdministrativeArea!
            : p.administrativeArea ?? 'Unknown');
        countryName = p.country ?? '';        // ← p scope ඇතුළේ
        countryCode = p.isoCountryCode ?? ''; // ← p scope ඇතුළේ
      }

  // ✅ TEST ONLY — මේ 2 lines add කරන්න මෙතන
    //  countryCode = 'US';
     // countryName = 'United States';
      // ✅ Cache save — NearbyFeed/Country screens දැන් GPS ඉල්ලන්නේ නෑ
      await LocationCacheService.instance.saveLocation(
        latitude   : _latitude!,
        longitude  : _longitude!,
        city       : city,
        countryName: countryName,
        countryCode: countryCode,
      );

      setState(() {
        _cityName        = city;
        _countryName     = countryName;
        _countryCode     = countryCode;
        _locationLoading = false;
        _locationGranted = true;
      });
      debugPrint('📍 Location: $_cityName ($_latitude, $_longitude)');
    } catch (e) {
      debugPrint('Fetch location error: $e');
      setState(() {
        _cityName = 'Location error';
        _locationLoading = false;
      });
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 📤 POST HANDLER — backend → Firestore 'text_posts'
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _handlePost() async {
    if (postContent
        .trim()
        .isEmpty || _isPosting) return;

    if (_latitude == null || _longitude == null) {
      _showSnack(
          '📍 Location needed. Tap "Allow location access"', isError: true);
      return;
    }

    setState(() => _isPosting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _showSnack('Not logged in!', isError: true);
        setState(() => _isPosting = false);
        return;
      }

      debugPrint('\n📤 ========== SENDING TEXT POST ==========');
      debugPrint('   uid         : $uid');
      debugPrint('   content     : ${postContent.trim().substring(0, postContent
          .trim()
          .length
          .clamp(0, 40))}...');
      debugPrint('   gradient    : $selectedGradient');
      debugPrint('   isAnonymous : $isAnonymous');
      debugPrint('   privacyMode : $privacyMode');
      debugPrint('   latitude    : $_latitude');
      debugPrint('   longitude   : $_longitude');
      debugPrint('   cityName    : $_cityName');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/text-posts/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': uid,
          'content': postContent.trim(),
          'gradientIndex': selectedGradient,
          'isAnonymous': isAnonymous,
          'privacyMode': privacyMode,
          'latitude': _latitude,
          'longitude': _longitude,
          'cityName': _cityName,
          'countryCode': _countryCode,
          'countryName': _countryName,
        }),
      ).timeout(const Duration(seconds: 30));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('📥 Response ${response.statusCode}: $body');

      if (response.statusCode == 201 && body['success'] == true) {
        debugPrint('✅ Text post saved! ID: ${body['postId']}');
        debugPrint('==========================================\n');
        if (mounted) {
          _showSnack('✅ Vibe posted!', isError: false);
          await Future.delayed(const Duration(milliseconds: 400));
          Navigator.pop(context, body['postId']);
        }
      } else {
        _showSnack(body['message'] as String? ?? 'Post failed', isError: true);
      }
    } catch (e) {
      debugPrint('❌ Post error: $e');
      _showSnack('Failed to post. Check connection.', isError: true);
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 🎨 BUILD
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final remaining = _maxChars - postContent.length;
    final pct = postContent.length / _maxChars;
    Color ringColor;
    if (remaining > 100)
      ringColor = Colors.white70;
    else if (remaining > 20)
      ringColor = Colors.orange;
    else
      ringColor = Colors.redAccent;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(gradient: gradients[selectedGradient]),
        child: SafeArea(
          child: Column(children: [

            // ── AppBar ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close
                  _glassButton(
                    child: const Icon(
                        Icons.close, color: Colors.white, size: 20),
                    onTap: () => Navigator.pop(context),
                  ),

                  // Anonymous toggle
                  GestureDetector(
                    onTap: () => setState(() => isAnonymous = !isAnonymous),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isAnonymous
                            ? Colors.white.withOpacity(0.25)
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(
                            0.3)),
                      ),
                      child: Row(children: [
                        Icon(isAnonymous ? Icons.visibility_off : Icons.person,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          isAnonymous ? 'Anonymous' : 'Public Name',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ]),
                    ),
                  ),

                  // Post button
                  GestureDetector(
                    onTap: (postContent
                        .trim()
                        .isNotEmpty && !_isPosting) ? _handlePost : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: postContent
                            .trim()
                            .isNotEmpty
                            ? Colors.white.withOpacity(0.9)
                            : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: postContent
                            .trim()
                            .isNotEmpty
                            ? [BoxShadow(color: Colors.white.withOpacity(0.2),
                            blurRadius: 12)
                        ]
                            : [],
                      ),
                      child: _isPosting
                          ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black54))
                          : Text('Post', style: TextStyle(
                          color: postContent
                              .trim()
                              .isNotEmpty
                              ? Colors.black87 : Colors.white54,
                          fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),

            // ── Text editor ────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    maxLines: null,
                    textAlign: TextAlign.center,
                    maxLength: _maxChars,
                    style: const TextStyle(
                        fontSize: 24, color: Colors.white,
                        fontWeight: FontWeight.bold, height: 1.4),
                    decoration: const InputDecoration(
                      hintText: "What's the vibe?",
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 24,
                          fontWeight: FontWeight.bold),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                    onChanged: (val) => setState(() => postContent = val),
                  ),
                ),
              ),
            ),

            // ── Character ring ─────────────────────────────────────────────
            if (postContent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: 36, height: 36,
                  child: Stack(fit: StackFit.expand, children: [
                    CircularProgressIndicator(
                        value: pct, strokeWidth: 3,
                        backgroundColor: Colors.white24, color: ringColor),
                    if (remaining <= 50)
                      Center(child: Text('$remaining',
                          style: TextStyle(color: ringColor, fontSize: 10,
                              fontWeight: FontWeight.bold))),
                  ]),
                ),
              ),

            // ── Location + privacy chip ────────────────────────────────────
            _buildLocationSection(),

            // ── Gradient switcher ──────────────────────────────────────────
            _buildGradientSwitcher(),
          ]),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 📍 Location section
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildLocationSection() {
    return Column(children: [
      // Location + Privacy chip (tap → privacy picker)
      GestureDetector(
        onTap: _showPrivacyPicker,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _locationLoading
                ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white70))
                : const Icon(
                Icons.location_on_rounded, color: Colors.redAccent, size: 18),
            const SizedBox(width: 6),
            Text(
              '$_cityName  |  $privacyMode',
              style: const TextStyle(color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white70),
          ]),
        ),
      ),

      // Allow location button (only when no location yet)
      if (!_locationGranted || _latitude == null)
        GestureDetector(
          onTap: _locationLoading ? null : _checkAndFetchLocation,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(
                  Icons.my_location_rounded, color: Colors.white70, size: 15),
              const SizedBox(width: 6),
              Text(
                _locationLoading
                    ? 'Getting location…'
                    : 'Allow location access',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ]),
          ),
        ),

      // Refresh button (once location is set)
      if (_locationGranted && _latitude != null)
        GestureDetector(
          onTap: _locationLoading ? null : _fetchCurrentLocation,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(
                  Icons.refresh_rounded, color: Colors.white38, size: 13),
              const SizedBox(width: 4),
              Text(
                _locationLoading ? 'Refreshing…' : 'Refresh location',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ]),
          ),
        ),
    ]);
  }

  // ── Gradient switcher ────────────────────────────────────────────────────────
  Widget _buildGradientSwitcher() {
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: gradients.length,
        itemBuilder: (context, index) {
          final isSelected = selectedGradient == index;
          return GestureDetector(
            onTap: () => setState(() => selectedGradient = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                gradient: gradients[index],
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(
                      0.3),
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: dotColors[index].withOpacity(0.5),
                    blurRadius: 10, spreadRadius: 2)
                ]
                    : [],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Glass button ─────────────────────────────────────────────────────────────
  Widget _glassButton({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: child,
      ),
    );
  }

  // ── Privacy picker ────────────────────────────────────────────────────────────
  void _showPrivacyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a2e).withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24,
                    borderRadius: BorderRadius.circular(4)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Who can see this post?',
                    style: TextStyle(color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
              const Divider(color: Colors.white12),
              _privacyTile(
                icon: Icons.public_rounded,  iconColor: Colors.greenAccent,
                title: 'Public',            subtitle: 'Visible to everyone worldwide',
                value: 'Public',
                ctx: ctx, // ← Add this
              ),
              _privacyTile(
                icon: Icons.near_me_rounded, iconColor: Colors.blueAccent,
                title: 'Nearby Only',       subtitle: 'Visible to people near you',
                value: 'Nearby Only',
                ctx: ctx, // ← Add this
              ),
              const SizedBox(height: 16),
            ]),
          ),
    );
  }

  Widget _privacyTile({
    required IconData icon, required Color iconColor,
    required String title, required String subtitle,
    required String value,
    required BuildContext ctx, // ← Add this parameter
  }) {
    final isSelected = privacyMode == value;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15), shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: TextStyle(color: Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: isSelected
          ? const Icon(
          Icons.check_circle_rounded, color: Colors.greenAccent, size: 20)
          : null,
      onTap: () {
        setState(() => privacyMode = value);
        Navigator.pop(ctx);
      },
    );
  }
}