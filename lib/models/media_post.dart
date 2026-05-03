import 'package:cloud_firestore/cloud_firestore.dart';

class MediaPost {
  String? id;
  String? uid;
  String? username;
  String? userEmail;  // ✅ Added this field
  String? mediaUrl;
  String? description;
  List<String>? hashtags;
  String? whoCanView;
  bool isActive;
  Timestamp? timestamp;
  String? type; // "image" or "video"
  String? profilePicUrl;
  int likes;
  int comments;
  String? musicTitle;
  String? audioUrl; // Audio track URL
  String? profileImageUrl; // Creator profile image URL
  List<String>? likedBy; // Add liked_by field for like functionality
  String? postId;

  MediaPost({
    this.id,
    this.uid,
    this.username,
    required this.userEmail,  // ✅ Required parameter
    this.mediaUrl,
    this.description,
    this.hashtags,
    this.whoCanView,
    this.isActive = true,
    this.timestamp,
    this.type,
    this.profilePicUrl,
    this.likes = 0,
    this.comments = 0,
    this.musicTitle,
    this.audioUrl,
    this.profileImageUrl,
    this.likedBy,
    this.postId,
  });

  // Factory constructor to create MediaPost from Firestore document
  factory MediaPost.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return MediaPost(
      id: doc.id,
      uid: data['uid'] as String?,
      username: data['username'] as String?,
      userEmail: data['user_email'] as String? ?? '',  // ✅ Added
      mediaUrl: data['media_url'] as String?,
      description: data['description'] as String?,
      hashtags: data['hashtags'] != null
          ? List<String>.from(data['hashtags'])
          : null,
      whoCanView: data['who_can_view'] as String?,
      isActive: data['is_active'] ?? true,
      timestamp: data['timestamp'] as Timestamp?,
      type: data['type'] as String?,
      profilePicUrl: data['profilePicUrl'] as String?,
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      musicTitle: data['musicTitle'] as String?,
      audioUrl: data['audioUrl'] as String?,
      profileImageUrl: data['profileImageUrl'] as String?,
      likedBy: data['liked_by'] != null
          ? List<String>.from(data['liked_by'])
          : null,
      postId: doc.id,
    );
  }

  // Factory constructor to create MediaPost from Map
  factory MediaPost.fromMap(Map<String, dynamic> map) {
    return MediaPost(
      id: map['id'] as String?,
      uid: map['uid'] as String?,
      username: map['username'] as String?,
      userEmail: map['user_email'] as String? ?? '',  // ✅ Added
      mediaUrl: map['media_url'] as String?,
      description: map['description'] as String?,
      hashtags: map['hashtags'] != null
          ? List<String>.from(map['hashtags'])
          : null,
      whoCanView: map['who_can_view'] as String?,
      isActive: map['is_active'] ?? true,
      timestamp: map['timestamp'] as Timestamp?,
      type: map['type'] as String?,
      profilePicUrl: map['profilePicUrl'] as String?,
      likes: map['likes'] ?? 0,
      comments: map['comments'] ?? 0,
      musicTitle: map['musicTitle'] as String?,
      audioUrl: map['audioUrl'] as String?,
      profileImageUrl: map['profileImageUrl'] as String?,
      likedBy: map['liked_by'] != null
          ? List<String>.from(map['liked_by'])
          : null,
      postId: map['postId'] as String?,
    );
  }

  // Convert MediaPost to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'user_email': userEmail,  // ✅ Added
      'media_url': mediaUrl,
      'description': description,
      'hashtags': hashtags,
      'who_can_view': whoCanView,
      'is_active': isActive,
      'timestamp': timestamp,
      'type': type,
      'profilePicUrl': profilePicUrl,
      'likes': likes,
      'comments': comments,
      'musicTitle': musicTitle,
      'audioUrl': audioUrl,
      'profileImageUrl': profileImageUrl,
      'liked_by': likedBy,
    };
  }

  // Helper methods (matching Java methods)

  /// Returns the music info (title)
  String? get musicInfo => musicTitle;

  /// Returns the uploader UID (owner's UID)
  String? get uploaderUid => uid;

  /// Returns the Firestore document ID
  String? get documentId => id;

  /// Get postId (returns the document ID consistently)
  String? getPostId() => id;

  /// Get privacy setting
  String? get privacy => whoCanView;

  // Copy with method for easy updates
  MediaPost copyWith({
    String? id,
    String? uid,
    String? username,
    String? userEmail,  // ✅ Added
    String? mediaUrl,
    String? description,
    List<String>? hashtags,
    String? whoCanView,
    bool? isActive,
    Timestamp? timestamp,
    String? type,
    String? profilePicUrl,
    int? likes,
    int? comments,
    String? musicTitle,
    String? audioUrl,
    String? profileImageUrl,
    List<String>? likedBy,
    String? postId,
  }) {
    return MediaPost(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      username: username ?? this.username,
      userEmail: userEmail ?? this.userEmail,  // ✅ Added
      mediaUrl: mediaUrl ?? this.mediaUrl,
      description: description ?? this.description,
      hashtags: hashtags ?? this.hashtags,
      whoCanView: whoCanView ?? this.whoCanView,
      isActive: isActive ?? this.isActive,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      musicTitle: musicTitle ?? this.musicTitle,
      audioUrl: audioUrl ?? this.audioUrl,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      likedBy: likedBy ?? this.likedBy,
      postId: postId ?? this.postId,
    );
  }
}