import 'package:my_vibe_flick/Notification/audio_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';


class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('uploaded_audio.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE uploaded_tracks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        duration INTEGER NOT NULL,
        localPath TEXT NOT NULL,
        uploadedAt TEXT NOT NULL,
        sourceType TEXT NOT NULL
      )
    ''');
  }

  // Insert uploaded track
  Future<void> insertTrack(AudioTrackEnhanced track) async {
    final db = await database;
    await db.insert(
      'uploaded_tracks',
      {
        'id': track.id,
        'title': track.title,
        'artist': track.artist,
        'duration': track.duration,
        'localPath': track.localPath,
        'uploadedAt': DateTime.now().toIso8601String(),
        'sourceType': track.category,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all uploaded tracks
  Future<List<AudioTrackEnhanced>> getAllUploadedTracks() async {
    final db = await database;
    final result = await db.query('uploaded_tracks', orderBy: 'uploadedAt DESC');

    return result.map((json) {
      return AudioTrackEnhanced(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        duration: json['duration'] as int,
        coverUrl: 'https://via.placeholder.com/60',
        audioUrl: json['localPath'] as String,
        category: 'Uploaded',
        localPath: json['localPath'] as String,
      );
    }).toList();
  }

  // Update track (for rename functionality)
  Future<void> updateTrack(AudioTrackEnhanced track) async {
    final db = await database;
    await db.update(
      'uploaded_tracks',
      {
        'title': track.title,
        'artist': track.artist,
        'duration': track.duration,
        'localPath': track.localPath,
        'sourceType': track.category,
      },
      where: 'id = ?',
      whereArgs: [track.id],
    );
  }

  // Delete track
  Future<void> deleteTrack(String id) async {
    final db = await database;
    await db.delete(
      'uploaded_tracks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }


}