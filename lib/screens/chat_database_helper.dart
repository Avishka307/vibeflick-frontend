import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ChatDatabaseHelper {
  static final ChatDatabaseHelper instance = ChatDatabaseHelper._init();
  static Database? _database;

  ChatDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('chat_cache.db');
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
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        chatRoomId TEXT NOT NULL,
        senderId TEXT NOT NULL,
        receiverId TEXT NOT NULL,
        message TEXT NOT NULL,
        type TEXT NOT NULL,
        mediaUrl TEXT,
        timestamp INTEGER NOT NULL,
        isSeen INTEGER NOT NULL,
        isSent INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_chatroom ON messages(chatRoomId, timestamp DESC)
    ''');
  }

  // ═══════════════ INSERT MESSAGE ═══════════════
  Future<void> insertMessage(Map<String, dynamic> message) async {
    final db = await database;
    await db.insert(
      'messages',
      message,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ═══════════════ GET MESSAGES (PAGINATION) ═══════════════
  Future<List<Map<String, dynamic>>> getMessages(
      String chatRoomId, {
        int limit = 20,
        int? lastTimestamp,
      }) async {
    final db = await database;

    if (lastTimestamp == null) {
      return await db.query(
        'messages',
        where: 'chatRoomId = ?',
        whereArgs: [chatRoomId],
        orderBy: 'timestamp DESC',
        limit: limit,
      );
    } else {
      return await db.query(
        'messages',
        where: 'chatRoomId = ? AND timestamp < ?',
        whereArgs: [chatRoomId, lastTimestamp],
        orderBy: 'timestamp DESC',
        limit: limit,
      );
    }
  }

  // ═══════════════ UPDATE MESSAGE SEEN STATUS ═══════════════
  Future<void> markAsSeen(String messageId) async {
    final db = await database;
    await db.update(
      'messages',
      {'isSeen': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // ═══════════════ DELETE OLD MESSAGES ═══════════════
  Future<void> deleteOldMessages(String chatRoomId, int keepLast) async {
    final db = await database;
    final messages = await db.query(
      'messages',
      where: 'chatRoomId = ?',
      whereArgs: [chatRoomId],
      orderBy: 'timestamp DESC',
    );

    if (messages.length > keepLast) {
      final messagesToDelete = messages.sublist(keepLast);
      for (var msg in messagesToDelete) {
        await db.delete(
          'messages',
          where: 'id = ?',
          whereArgs: [msg['id']],
        );
      }
    }
  }

  // ═══════════════ CLEAR ALL CACHE ═══════════════
  Future<void> clearAllCache() async {
    final db = await database;
    await db.delete('messages');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}