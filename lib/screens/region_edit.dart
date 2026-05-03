import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// pubspec.yaml එකෙ add කරන්න:
//   geolocator: ^11.0.0
//   geocoding: ^3.0.0
//
// Android → android/app/src/main/AndroidManifest.xml:
//   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
//
// iOS → ios/Runner/Info.plist:
//   <key>NSLocationWhenInUseUsageDescription</key>
//   <string>Used to detect your region</string>

// ══════════════════════════════════════════════════════════════
// Main Edit Region Screen
// ══════════════════════════════════════════════════════════════
class RegionEditScreen extends StatefulWidget {
  final String currentRegion;

  const RegionEditScreen({
    super.key,
    required this.currentRegion,
  });

  @override
  State<RegionEditScreen> createState() => _RegionEditScreenState();
}

class _RegionEditScreenState extends State<RegionEditScreen> {
  bool isSaving = false;
  bool showRegionTag = true;
  late String selectedRegion;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    selectedRegion = widget.currentRegion;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          showRegionTag = doc.data()?['show_region_tag'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error loading region settings: $e');
    }
  }

  Future<void> _handleSave() async {
    final user = _auth.currentUser;
    if (user == null) return;
    HapticFeedback.mediumImpact();
    setState(() => isSaving = true);
    try {
      // ✅ Firestore users collection → region + show_region_tag save
      await _firestore.collection('users').doc(user.uid).update({
        'region': selectedRegion,
        'show_region_tag': showRegionTag,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context, selectedRegion);
    } catch (e) {
      debugPrint('Error saving region: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Failed to save region'),
          ]),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> _openRegionSelector() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => RegionSelectScreen(selectedRegion: selectedRegion),
      ),
    );
    // ✅ RegionSelectScreen ගෙ manual හෝ GPS region return වෙනවා
    if (result != null) {
      setState(() => selectedRegion = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLocationCard(),
                    _buildSectionHeader('Publicly display'),
                    _buildPublicCard(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 24, color: Colors.white),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  padding: const EdgeInsets.all(4),
                ),
                const Expanded(
                  child: Text(
                    'Edit region',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: isSaving
                      ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFFF3B5C)),
                    ),
                  )
                      : TextButton(
                    onPressed: _handleSave,
                    child: const Text('Save',
                        style: TextStyle(
                            color: Color(0xFFFF3B5C),
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
            color: Color(0xFF888888), fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: _openRegionSelector,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                const Text('Location',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                Text(
                  selectedRegion.isEmpty ? 'Not set' : selectedRegion,
                  style: const TextStyle(color: Color(0xFF888888), fontSize: 15),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    color: Color(0xFF888888), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPublicCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Text('Show region tag',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            // ✅ toggle ON → Firestore save_region_tag: true
            // → profile_screen.dart _buildProfileTags() region chip show වෙනවා
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                setState(() => showRegionTag = !showRegionTag);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 52,
                height: 32,
                decoration: BoxDecoration(
                  color: showRegionTag
                      ? const Color(0xFFFF3B5C)
                      : const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: showRegionTag
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Region Select Screen — Manual list + Optional GPS
// ══════════════════════════════════════════════════════════════
class RegionSelectScreen extends StatefulWidget {
  final String selectedRegion;

  const RegionSelectScreen({super.key, required this.selectedRegion});

  @override
  State<RegionSelectScreen> createState() => _RegionSelectScreenState();
}

class _RegionSelectScreenState extends State<RegionSelectScreen> {
  late String _selected;

  // ✅ false → screen open වෙනකොට GPS permission ඉල්ලන්නේ නැ
  // true → user tap කළාම loading show + GPS run
  bool _isDetectingLocation = false;

  final List<String> _allRegions = const [
    'Afghanistan', 'Albania', 'Algeria', 'Andorra', 'Angola',
    'Antigua and Barbuda', 'Argentina', 'Armenia', 'Aruba', 'Australia',
    'Austria', 'Azerbaijan', 'Bahamas', 'Bahrain', 'Bangladesh',
    'Barbados', 'Belarus', 'Belgium', 'Belize', 'Benin', 'Bhutan',
    'Bolivia', 'Bosnia and Herzegovina', 'Botswana', 'Brazil', 'Brunei',
    'Bulgaria', 'Burkina Faso', 'Burundi', 'Cabo Verde', 'Cambodia',
    'Cameroon', 'Canada', 'Central African Republic', 'Chad', 'Chile',
    'China', 'Colombia', 'Comoros', 'Congo', 'Costa Rica', 'Croatia',
    'Cuba', 'Cyprus', 'Czech Republic', 'Denmark', 'Djibouti', 'Dominica',
    'Dominican Republic', 'Ecuador', 'Egypt', 'El Salvador',
    'Equatorial Guinea', 'Eritrea', 'Estonia', 'Eswatini', 'Ethiopia',
    'Fiji', 'Finland', 'France', 'Gabon', 'Gambia', 'Georgia', 'Germany',
    'Ghana', 'Greece', 'Grenada', 'Guatemala', 'Guinea', 'Guinea-Bissau',
    'Guyana', 'Haiti', 'Honduras', 'Hungary', 'Iceland', 'India',
    'Indonesia', 'Iran', 'Iraq', 'Ireland', 'Israel', 'Italy', 'Jamaica',
    'Japan', 'Jordan', 'Kazakhstan', 'Kenya', 'Kiribati', 'Kuwait',
    'Kyrgyzstan', 'Laos', 'Latvia', 'Lebanon', 'Lesotho', 'Liberia',
    'Libya', 'Liechtenstein', 'Lithuania', 'Luxembourg', 'Madagascar',
    'Malawi', 'Malaysia', 'Maldives', 'Mali', 'Malta', 'Marshall Islands',
    'Mauritania', 'Mauritius', 'Mexico', 'Micronesia', 'Moldova', 'Monaco',
    'Mongolia', 'Montenegro', 'Morocco', 'Mozambique', 'Myanmar', 'Namibia',
    'Nauru', 'Nepal', 'Netherlands', 'New Zealand', 'Nicaragua', 'Niger',
    'Nigeria', 'North Korea', 'North Macedonia', 'Norway', 'Oman',
    'Pakistan', 'Palau', 'Palestine', 'Panama', 'Papua New Guinea',
    'Paraguay', 'Peru', 'Philippines', 'Poland', 'Portugal', 'Qatar',
    'Romania', 'Russia', 'Rwanda', 'Saint Kitts and Nevis', 'Saint Lucia',
    'Saint Vincent and the Grenadines', 'Samoa', 'San Marino',
    'Sao Tome and Principe', 'Saudi Arabia', 'Senegal', 'Serbia',
    'Seychelles', 'Sierra Leone', 'Singapore', 'Slovakia', 'Slovenia',
    'Solomon Islands', 'Somalia', 'South Africa', 'South Korea',
    'South Sudan', 'Spain', 'Sri Lanka', 'Sudan', 'Suriname', 'Sweden',
    'Switzerland', 'Syria', 'Taiwan', 'Tajikistan', 'Tanzania', 'Thailand',
    'Timor-Leste', 'Togo', 'Tonga', 'Trinidad and Tobago', 'Tunisia',
    'Turkey', 'Turkmenistan', 'Tuvalu', 'Uganda', 'Ukraine',
    'United Arab Emirates', 'United Kingdom', 'United States', 'Uruguay',
    'Uzbekistan', 'Vanuatu', 'Vatican City', 'Venezuela', 'Vietnam',
    'Yemen', 'Zambia', 'Zimbabwe',
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedRegion;
    // ✅ initState ගෙ GPS ඉල්ලන්නේ නැ — manual list FIRST
  }

  // ══════════════════════════════════════════════════════════
  // GPS FLOW — "Please allow access" card tap කළාම විතරක් run
  //
  //  Step 1: Location service on ද?
  //  Step 2: Permission already granted ද?
  //  Step 3: Denied නම් → permission dialog show
  //  Step 4: Permission OK → getCurrentPosition() (low accuracy)
  //  Step 5: placemarkFromCoordinates() → country name
  //  Step 6: List ඇතිළේ match → _selected update → checkmark
  // ══════════════════════════════════════════════════════════
  Future<void> _detectLocation() async {
    HapticFeedback.mediumImpact();
    setState(() => _isDetectingLocation = true);

    try {
      // Step 1
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('GPS disabled. Please enable location services.');
        setState(() => _isDetectingLocation = false);
        return;
      }

      // Step 2 & 3
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Location permission denied.');
          setState(() => _isDetectingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack('Please enable location from app settings.');
        setState(() => _isDetectingLocation = false);
        return;
      }

      // Step 4 — low accuracy = faster, battery friendly
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      debugPrint('📍 ${position.latitude}, ${position.longitude}');

      // Step 5
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final raw = placemarks.first.country ?? '';
        debugPrint('🌍 Detected: $raw');

        if (raw.isNotEmpty) {
          // Step 6
          final matched = _matchCountry(raw);
          setState(() {
            _selected = matched ?? raw; // checkmark update
            _isDetectingLocation = false;
          });
          _showSnack('📍 ${_selected}', isSuccess: true);
        } else {
          _showSnack('Could not detect country. Select manually.');
          setState(() => _isDetectingLocation = false);
        }
      } else {
        _showSnack('Could not detect location. Select manually.');
        setState(() => _isDetectingLocation = false);
      }
    } catch (e) {
      debugPrint('❌ GPS error: $e');
      _showSnack('Detection failed. Please select manually.');
      setState(() => _isDetectingLocation = false);
    }
  }

  // Detected name → list match (exact → partial → alias)
  String? _matchCountry(String raw) {
    final lower = raw.toLowerCase().trim();
    for (final r in _allRegions) {
      if (r.toLowerCase() == lower) return r;
    }
    for (final r in _allRegions) {
      if (r.toLowerCase().contains(lower) || lower.contains(r.toLowerCase())) {
        return r;
      }
    }
    const aliases = {
      'united states of america': 'United States',
      'usa': 'United States',
      'uk': 'United Kingdom',
      'great britain': 'United Kingdom',
      'england': 'United Kingdom',
      'scotland': 'United Kingdom',
      'wales': 'United Kingdom',
      'republic of ireland': 'Ireland',
      'republic of korea': 'South Korea',
      "democratic people's republic of korea": 'North Korea',
      'czechia': 'Czech Republic',
      'viet nam': 'Vietnam',
      'myanmar (burma)': 'Myanmar',
      'lao pdr': 'Laos',
    };
    return aliases[lower];
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isSuccess ? Icons.check_circle : Icons.info_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor:
      isSuccess ? const Color(0xFF4CAF50) : const Color(0xFF2C2C2C),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── AppBar ─────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: const Text('Cancel',
                            style: TextStyle(
                                color: Color(0xFF888888), fontSize: 16)),
                      ),
                      const Expanded(
                        child: Text('Select region',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 56),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── GPS Card — tap කළාම විතරක් permission dialog ─────
          _buildSectionHeader('Location'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              // ✅ TAP → _detectLocation() → permission dialog → GPS → country
              onTap: _isDetectingLocation ? null : _detectLocation,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F1F),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: _isDetectingLocation
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF2196F3),
                            ),
                          )
                              : const Icon(Icons.location_on,
                              color: Color(0xFF2196F3), size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isDetectingLocation
                              ? 'Detecting your location...'
                              : 'Please allow access to your location',
                          style: TextStyle(
                            color: _isDetectingLocation
                                ? const Color(0xFF2196F3)
                                : Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (!_isDetectingLocation)
                        const Icon(Icons.chevron_right,
                            color: Color(0xFF4A4A4A), size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Manual list ────────────────────────────────────
          _buildSectionHeader('All regions'),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  itemCount: _allRegions.length,
                  separatorBuilder: (_, __) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    height: 1,
                    color: const Color(0xFF2C2C2C),
                  ),
                  itemBuilder: (context, index) {
                    final region = _allRegions[index];
                    final isSelected = region == _selected;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selected = region);
                        // ✅ checkmark 180ms show → RegionEditScreen → selectedRegion update
                        Future.delayed(const Duration(milliseconds: 180), () {
                          if (mounted) Navigator.pop(context, region);
                        });
                      },
                      child: Container(
                        color: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                region,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFFFF3B5C)
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            isSelected
                                ? const Icon(Icons.check,
                                color: Color(0xFFFF3B5C), size: 20)
                                : const SizedBox(width: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title,
          style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 14,
              fontWeight: FontWeight.w500)),
    );
  }
}