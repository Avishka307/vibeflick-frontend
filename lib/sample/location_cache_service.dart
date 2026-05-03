import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  📍 LocationCacheService
//  • User ගේ location එකපාරක් ගත්තාම cache කරනවා
//  • Nearby/Country/Global screens වලදී GPS call නකරා cached data use කරනවා
//  • Battery saving + UX improvement
// ─────────────────────────────────────────────────────────────────────────────

class LocationCacheService {
  LocationCacheService._();
  static final LocationCacheService instance = LocationCacheService._();

  // ── SharedPreferences keys ──────────────────────────────────────────────────
  static const _kLat         = 'loc_latitude';
  static const _kLng         = 'loc_longitude';
  static const _kCity        = 'loc_city';
  static const _kCountryName = 'loc_country_name';
  static const _kCountryCode = 'loc_country_code';
  static const _kTimestamp   = 'loc_timestamp';

  // Cache validity: 6 hours (user can refresh manually)
  static const _cacheValidMs = 6 * 60 * 60 * 1000;

  // ── In-memory cache (app session) ──────────────────────────────────────────
  double? _latitude;
  double? _longitude;
  String? _city;
  String? _countryName;
  String? _countryCode;

  bool get hasCachedLocation =>
      _latitude != null && _longitude != null;

  double? get latitude     => _latitude;
  double? get longitude    => _longitude;
  String  get city         => _city        ?? 'Nearby';
  String  get countryName  => _countryName ?? '';
  String  get countryCode  => _countryCode ?? '';

  // ── Save location (call after first GPS fetch) ──────────────────────────────
  Future<void> saveLocation({
    required double latitude,
    required double longitude,
    required String city,
    required String countryName,
    required String countryCode,
  }) async {
    // In-memory
    _latitude    = latitude;
    _longitude   = longitude;
    _city        = city;
    _countryName = countryName;
    _countryCode = countryCode;

    // Persistent
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLat,         latitude);
    await prefs.setDouble(_kLng,         longitude);
    await prefs.setString(_kCity,        city);
    await prefs.setString(_kCountryName, countryName);
    await prefs.setString(_kCountryCode, countryCode);
    await prefs.setInt(_kTimestamp,      DateTime.now().millisecondsSinceEpoch);
  }

  // ── Load from SharedPreferences (app start) ─────────────────────────────────
  Future<bool> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final lat  = prefs.getDouble(_kLat);
    final lng  = prefs.getDouble(_kLng);
    final ts   = prefs.getInt(_kTimestamp) ?? 0;

    if (lat == null || lng == null) return false;

    // Check cache validity
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > _cacheValidMs) return false; // stale - needs refresh

    _latitude    = lat;
    _longitude   = lng;
    _city        = prefs.getString(_kCity)        ?? 'Nearby';
    _countryName = prefs.getString(_kCountryName) ?? '';
    _countryCode = prefs.getString(_kCountryCode) ?? '';

    return true;
  }

  // ── Force clear (eg. user logout) ─────────────────────────────────────────
  Future<void> clear() async {
    _latitude = _longitude = null;
    _city = _countryName = _countryCode = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLat);
    await prefs.remove(_kLng);
    await prefs.remove(_kCity);
    await prefs.remove(_kCountryName);
    await prefs.remove(_kCountryCode);
    await prefs.remove(_kTimestamp);
  }
}