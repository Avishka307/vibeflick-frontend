// ============================================================
//  text_post_controller.dart
//  Post button එකේ logic, location ගන්නා ක්‍රමය,
//  Firebase save — සියල්ල මෙතන.
//  State management: ChangeNotifier (Riverpod නැතිව)
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';

import 'text_post_model.dart';

// ---------------------------------------------------------------
//  UI State — screen එකේ loading / error / success
// ---------------------------------------------------------------
enum PostingStatus { idle, locating, uploading, success, error }

class TextPostState {
  final String text;
  final PostBackground background;
  final PostFontStyle fontStyle;
  final List<StickerPlacement> stickers;
  final bool isNearbyOnly;
  final PostingStatus status;
  final String? errorMessage;

  const TextPostState({
    this.text = '',
    this.background = PostBackground.saffron,
    this.fontStyle = PostFontStyle.clean,
    this.stickers = const [],
    this.isNearbyOnly = false,
    this.status = PostingStatus.idle,
    this.errorMessage,
  });

  TextPostState copyWith({
    String? text,
    PostBackground? background,
    PostFontStyle? fontStyle,
    List<StickerPlacement>? stickers,
    bool? isNearbyOnly,
    PostingStatus? status,
    String? errorMessage,
  }) {
    return TextPostState(
      text: text ?? this.text,
      background: background ?? this.background,
      fontStyle: fontStyle ?? this.fontStyle,
      stickers: stickers ?? this.stickers,
      isNearbyOnly: isNearbyOnly ?? this.isNearbyOnly,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  bool get canPost => text.trim().isNotEmpty && status == PostingStatus.idle;
}

// ---------------------------------------------------------------
//  TextPostController (ChangeNotifier)
// ---------------------------------------------------------------
class TextPostController extends ChangeNotifier {
  TextPostState _state = const TextPostState();
  TextPostState get state => _state;

  void _setState(TextPostState newState) {
    _state = newState;
    notifyListeners();
  }

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // -- UI updates (style bar changes) ---------------------------

  void onTextChanged(String value) =>
      _setState(_state.copyWith(text: value, status: PostingStatus.idle));

  void onBackgroundChanged(PostBackground bg) =>
      _setState(_state.copyWith(background: bg));

  void onFontStyleChanged(PostFontStyle fs) =>
      _setState(_state.copyWith(fontStyle: fs));

  void onNearbyToggled(bool value) =>
      _setState(_state.copyWith(isNearbyOnly: value));

  void addSticker(StickerPlacement sticker) {
    _setState(_state.copyWith(stickers: [..._state.stickers, sticker]));
  }

  void removeSticker(int index) {
    final updated = List<StickerPlacement>.from(_state.stickers)
      ..removeAt(index);
    _setState(_state.copyWith(stickers: updated));
  }

  // -- Post button එබුවම ----------------------------------------

  Future<void> submitPost(BuildContext context) async {
    if (!_state.canPost) return;

    try {
      // 1. Location ගන්නවා
      _setState(_state.copyWith(status: PostingStatus.locating));
      final position = await _getCurrentLocation();
      final cityName = await _getCityName(position);

      // 2. Firebase Firestore save
      _setState(_state.copyWith(status: PostingStatus.uploading));

      final user = _auth.currentUser;
      if (user == null) throw Exception('Please log in first.');

      final postId = const Uuid().v4();
      final post = TextPostModel(
        id: postId,
        userId: user.uid,
        username: user.displayName ?? 'Anonymous',
        avatarUrl: user.photoURL ?? '',
        textContent: _state.text.trim(),
        background: _state.background,
        fontStyle: _state.fontStyle,
        stickers: _state.stickers,
        visibility: _state.isNearbyOnly
            ? PostVisibility.nearbyOnly
            : PostVisibility.everyone,
        location: GeoPoint(position.latitude, position.longitude),
        cityName: cityName,
        createdAt: DateTime.now(),
      );

      // Firestore collection: "text_posts"
      await _firestore
          .collection('text_posts')
          .doc(postId)
          .set(post.toFirestore());

      // 3. Success!
      _setState(_state.copyWith(status: PostingStatus.success));
      _resetAfterSuccess();
    } on LocationPermissionDeniedException catch (e) {
      _setState(_state.copyWith(
        status: PostingStatus.error,
        errorMessage: 'Location permission නැහැ: ${e.message}',
      ));
    } catch (e) {
      _setState(_state.copyWith(
        status: PostingStatus.error,
        errorMessage: 'Error: ${e.toString()}',
      ));
    }
  }

  // -- Location helpers -----------------------------------------

  Future<Position> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationPermissionDeniedException('Permission denied by user.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionDeniedException(
          'Location permission permanently denied. Settings වලින් on කරන්න.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 10),
    );
  }

  Future<String> _getCityName(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return place.locality ?? place.subAdministrativeArea ?? 'Sri Lanka';
      }
    } catch (_) {
      // Geocoding fail වුනත් post යනවා — city "Unknown" ලෙස
    }
    return 'Unknown';
  }

  void _resetAfterSuccess() {
    Future.delayed(const Duration(seconds: 2), () {
      _setState(const TextPostState());
    });
  }
}

// ---------------------------------------------------------------
//  Custom Exception
// ---------------------------------------------------------------
class LocationPermissionDeniedException implements Exception {
  final String message;
  LocationPermissionDeniedException(this.message);
  @override
  String toString() => message;
}