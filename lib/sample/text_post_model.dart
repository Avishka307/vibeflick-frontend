// ============================================================
//  text_post_model.dart
//  Text Post එකක data structure එක define කරන file එක.
//  Firebase Firestore එක්ක කෙලින්ම use කරන්න හදලා.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';

/// Text Post type enum — future-proof කරන්න
enum PostVisibility {
  everyone, // සියල්ලෝටම පෙනෙනවා
  nearbyOnly, // Nearby (km 10 ඇතුළත) අයට විතරක්
}

/// Font style enum
enum PostFontStyle {
  clean,
  bold,
  serif,
  boldSerif,
}

/// Background color/gradient enum
enum PostBackground {
  saffron,
  ocean,
  forest,
  sunset,
  night,
  thambili,
}

// ---------------------------------------------------------------
//  TextPostModel
// ---------------------------------------------------------------
class TextPostModel {
  final String id;
  final String userId;
  final String username;
  final String avatarUrl;

  final String textContent; // ලිව්ව message
  final PostBackground background; // තෝරාගත්ත background
  final PostFontStyle fontStyle; // Font style
  final List<StickerPlacement> stickers; // Drag-drop කළ sticker list

  final PostVisibility visibility; // everyone / nearbyOnly
  final GeoPoint location; // Post දාපු GPS point (Firebase GeoPoint)
  final String cityName; // "Colombo", "Kandy" ආදිය — display වලට

  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;

  const TextPostModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.textContent,
    required this.background,
    required this.fontStyle,
    required this.stickers,
    required this.visibility,
    required this.location,
    required this.cityName,
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
  });

  // ---------------------------------------------------------------
  //  Firebase → Dart (fromFirestore)
  // ---------------------------------------------------------------
  factory TextPostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return TextPostModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'Unknown',
      avatarUrl: data['avatarUrl'] ?? '',
      textContent: data['textContent'] ?? '',
      background: PostBackground.values.firstWhere(
            (e) => e.name == (data['background'] ?? 'saffron'),
        orElse: () => PostBackground.saffron,
      ),
      fontStyle: PostFontStyle.values.firstWhere(
            (e) => e.name == (data['fontStyle'] ?? 'clean'),
        orElse: () => PostFontStyle.clean,
      ),
      stickers: (data['stickers'] as List<dynamic>? ?? [])
          .map((s) => StickerPlacement.fromMap(s as Map<String, dynamic>))
          .toList(),
      visibility: data['visibility'] == 'nearbyOnly'
          ? PostVisibility.nearbyOnly
          : PostVisibility.everyone,
      location: data['location'] as GeoPoint,
      cityName: data['cityName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      likesCount: data['likesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
    );
  }

  // ---------------------------------------------------------------
  //  Dart → Firebase (toFirestore)
  // ---------------------------------------------------------------
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'textContent': textContent,
      'background': background.name,
      'fontStyle': fontStyle.name,
      'stickers': stickers.map((s) => s.toMap()).toList(),
      'visibility': visibility.name,
      'location': location,
      'cityName': cityName,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
    };
  }

  // ---------------------------------------------------------------
  //  copyWith — partial updates වලට
  // ---------------------------------------------------------------
  TextPostModel copyWith({
    int? likesCount,
    int? commentsCount,
  }) {
    return TextPostModel(
      id: id,
      userId: userId,
      username: username,
      avatarUrl: avatarUrl,
      textContent: textContent,
      background: background,
      fontStyle: fontStyle,
      stickers: stickers,
      visibility: visibility,
      location: location,
      cityName: cityName,
      createdAt: createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }
}

// ---------------------------------------------------------------
//  StickerPlacement — canvas එකේ sticker position
// ---------------------------------------------------------------
class StickerPlacement {
  final String emoji;
  final double xPercent; // 0.0 – 100.0  (canvas width %)
  final double yPercent; // 0.0 – 100.0  (canvas height %)

  const StickerPlacement({
    required this.emoji,
    required this.xPercent,
    required this.yPercent,
  });

  factory StickerPlacement.fromMap(Map<String, dynamic> map) {
    return StickerPlacement(
      emoji: map['emoji'] ?? '',
      xPercent: (map['xPercent'] as num).toDouble(),
      yPercent: (map['yPercent'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'emoji': emoji,
    'xPercent': xPercent,
    'yPercent': yPercent,
  };
}