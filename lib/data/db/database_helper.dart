import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../model/girlfriend.dart';
import '../model/chat_item.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ai_girlfriend.db');

    return await openDatabase(
      path,
      version: 7,
      onCreate: (db, version) async {
        // messages table stores messages per companion with unique message_id when available
        await db.execute(
          'CREATE TABLE messages(id INTEGER PRIMARY KEY AUTOINCREMENT, companion_id TEXT, message_id TEXT UNIQUE, role TEXT, content TEXT, image_path TEXT, image_status TEXT, generation_id TEXT, extra_message TEXT, time INTEGER)',
        );
        await _createGirlfriendsTable(db);
        await db.execute(
          'CREATE TABLE chat_list(companion_id TEXT PRIMARY KEY, name TEXT NOT NULL, image_url TEXT NOT NULL, last_text TEXT, time INTEGER)',
        );
        await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_companion ON messages(companion_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_message_id ON messages(message_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_companion_time ON messages(companion_id, time DESC)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_chat_list_time ON chat_list(time)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE messages ADD COLUMN image_path TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE messages ADD COLUMN image_status TEXT');
        }
        if (oldVersion < 5) {
          await _ensureMessagesExtraMessageColumn(db);
        }
        if (oldVersion < 6) {
          await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_companion_time ON messages(companion_id, time DESC)');
        }
        if (oldVersion < 7) {
          await _ensureMessagesGenerationIdColumn(db);
        }
      },
      onOpen: (db) async {
        await _ensureMessagesExtraMessageColumn(db);
        await _ensureMessagesGenerationIdColumn(db);
      },
    );
  }

  static Future<void> _ensureMessagesExtraMessageColumn(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(messages)');
    final has = cols.any((c) => (c['name'] as String?) == 'extra_message');
    if (!has) {
      await db.execute('ALTER TABLE messages ADD COLUMN extra_message TEXT');
    }
  }

  static Future<void> _ensureMessagesGenerationIdColumn(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(messages)');
    final has = cols.any((c) => (c['name'] as String?) == 'generation_id');
    if (!has) {
      await db.execute('ALTER TABLE messages ADD COLUMN generation_id TEXT');
    }
  }

  Future<void> _createGirlfriendsTable(Database db) async {
    await db.execute(
      'CREATE TABLE girlfriends(companion_id TEXT PRIMARY KEY, name TEXT NOT NULL, image_url TEXT NOT NULL, age INTEGER, tags TEXT)',
    );
  }

  Future<void> replaceGirlfriends(List<Girlfriend> list) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('girlfriends');
      if (list.isEmpty) return;
      final batch = txn.batch();
      for (final g in list) {
        batch.insert('girlfriends', {
          'companion_id': g.id,
          'name': g.name,
          'image_url': g.imageUrl,
          'age': g.age,
          'tags': g.tags.join(','),
        });
      }
      await batch.commit(noResult: true);
    });
  }

  /// Messages cache operations (per companion)
  Future<List<Map<String, dynamic>>> _rawGetMessages(
    String companionId, {
    List<String>? columns,
  }) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      columns: columns,
      where: 'companion_id = ?',
      whereArgs: [companionId],
      orderBy: 'time ASC',
      limit: 500,
    );
    return maps;
  }

  Future<List<dynamic>> getCachedMessages(String companionId) async {
    debugPrint("DatabaseHelper: Getting cached messages for companionId: $companionId");
    final rows = await _rawGetMessages(companionId);
    debugPrint("DatabaseHelper: Found ${rows.length} messages in cache for companionId: $companionId");
    return rows
        .map(
          (m) => {
            'companion_id': m['companion_id'],
            'message_id': m['message_id'],
            'role': m['role'],
            'content': m['content'],
            'image_path': m['image_path'],
            'image_status': m['image_status'],
            'generation_id': m['generation_id'] ?? '',
            'extra_message': m['extra_message'] ?? '',
            'time': m['time'],
          },
        )
        .toList();
  }

  /// Matches the last row of the history window, without loading message bodies.
  Future<String?> getCachedLastMessageRole(String companionId) async {
    final rows = await _rawGetMessages(companionId, columns: const ['role']);
    return rows.isEmpty ? null : (rows.last['role'] ?? '').toString();
  }

  Future<void> syncMessages(String companionId, List<dynamic> list) async {
    debugPrint("DatabaseHelper: Syncing ${list.length} messages for companionId: $companionId");
    final db = await database;

    // If the remote API returns an empty list, treat it as a source-of-truth "clear history"
    // and remove existing cached messages for this companion.
    if (list.isEmpty) {
      await db.delete('messages', where: 'companion_id = ?', whereArgs: [companionId]);
      return;
    }

    await db.transaction((txn) async {
      // 1. Upsert new messages
      if (list.isNotEmpty) {
        final deduped = _dedupeMessages(list, companionId);
        final batch = txn.batch();
        for (final m in deduped) {
          batch.insert('messages', {
            'companion_id': companionId,
            'message_id': _normalizedMessageId(m['message_id']),
            'role': m['role'] ?? '',
            'content': m['content'] ?? '',
            'image_path': m['image_path'] ?? '',
            'image_status': m['image_status'] ?? '',
            'generation_id': m['generation_id'] ?? '',
            'extra_message': m['extra_message'] ?? '',
            'time': m['time'] ?? 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }

      // 2. Trim to keep only last 500 messages
      // We subquery to find the IDs of the messages we want to KEEP (top 500 by time DESC)
      // Then delete those NOT in that list.
      // SQLite efficient way: DELETE FROM messages WHERE companion_id = ? AND id NOT IN (SELECT id FROM messages WHERE companion_id = ? ORDER BY time DESC LIMIT 500)

      try {
        await txn.rawDelete(
          'DELETE FROM messages WHERE companion_id = ? AND id NOT IN (SELECT id FROM messages WHERE companion_id = ? ORDER BY time DESC LIMIT 500)',
          [companionId, companionId],
        );
      } catch (e) {
        debugPrint("DatabaseHelper: Error trimming messages: $e");
      }
    });
    debugPrint("DatabaseHelper: Finished syncing messages for companionId: $companionId");
  }

  Future<void> upsertMessageItem(Map<String, dynamic> m) async {
    final companionId = m['companion_id'] ?? '';
    debugPrint("DatabaseHelper: Upserting message for companionId: $companionId");
    final db = await database;
    final normalizedMessageId = _normalizedMessageId(m['message_id']);
    if (normalizedMessageId == null) {
      final existing = await db.query(
        'messages',
        columns: ['id'],
        where: 'companion_id = ? AND role = ? AND content = ? AND time = ?',
        whereArgs: [m['companion_id'] ?? '', m['role'] ?? '', m['content'] ?? '', m['time'] ?? 0],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        debugPrint("DatabaseHelper: Skipping duplicate fallback message for companionId: $companionId");
        return;
      }
    }
    await db.insert('messages', {
      'companion_id': m['companion_id'] ?? '',
      'message_id': normalizedMessageId,
      'role': m['role'] ?? '',
      'content': m['content'] ?? '',
      'image_path': m['image_path'] ?? '',
      'image_status': m['image_status'] ?? '',
      'generation_id': m['generation_id'] ?? '',
      'extra_message': m['extra_message'] ?? '',
      'time': m['time'] ?? 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    debugPrint("DatabaseHelper: Finished upserting message for companionId: $companionId");
  }

  Future<void> deleteMessagesByCompanion(String companionId) async {
    debugPrint("DatabaseHelper: Deleting all messages for companionId: $companionId");
    final db = await database;
    await db.delete('messages', where: 'companion_id = ?', whereArgs: [companionId]);
    debugPrint("DatabaseHelper: Finished deleting messages for companionId: $companionId");
  }

  Future<List<Girlfriend>> getGirlfriends() async {
    final db = await database;
    final maps = await db.query('girlfriends', orderBy: 'companion_id ASC');
    return maps.map((m) => Girlfriend.fromMap(m)).toList();
  }

  /// Returns girlfriend by name, or null if not found.
  Future<Girlfriend?> getGirlfriendByName(String name) async {
    final db = await database;
    final maps = await db.query('girlfriends', where: 'name = ?', whereArgs: [name], limit: 1);
    if (maps.isEmpty) return null;
    return Girlfriend.fromMap(maps.first);
  }

  /// Chat list cache operations
  Future<List<ChatItem>> getCachedChats() async {
    final db = await database;
    final maps = await db.query('chat_list', orderBy: 'time DESC');
    return maps.map((m) {
      return ChatItem(
        companionId: (m['companion_id'] ?? '').toString(),
        girlfriendName: (m['name'] ?? '').toString(),
        lastText: (m['last_text'] ?? '').toString(),
        imageUrl: (m['image_url'] ?? '').toString(),
        time: (m['time'] is int) ? m['time'] as int : int.tryParse((m['time'] ?? '').toString()) ?? 0,
      );
    }).toList();
  }

  Future<void> replaceCachedChats(List<ChatItem> list) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('chat_list');
      if (list.isEmpty) return;
      final batch = txn.batch();
      for (final c in list) {
        batch.insert('chat_list', {
          'companion_id': c.companionId,
          'name': c.girlfriendName,
          'image_url': c.imageUrl,
          'last_text': c.lastText,
          'time': c.time,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertChatItem(ChatItem item) async {
    final db = await database;
    await db.insert('chat_list', {
      'companion_id': item.companionId,
      'name': item.girlfriendName,
      'image_url': item.imageUrl,
      'last_text': item.lastText,
      'time': item.time,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('chat_list');
      await txn.delete('messages');
    });
  }

  String? _normalizedMessageId(dynamic value) {
    final id = (value ?? '').toString().trim();
    return id.isEmpty ? null : id;
  }

  List<Map<String, dynamic>> _dedupeMessages(List<dynamic> list, String companionId) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final messageId = _normalizedMessageId(m['message_id']);
      final role = (m['role'] ?? '').toString();
      final content = (m['content'] ?? '').toString();
      final time = (m['time'] is int) ? m['time'] as int : int.tryParse((m['time'] ?? '').toString()) ?? 0;
      final key = messageId ?? '$companionId|$role|$time|$content';
      if (seen.contains(key)) continue;
      seen.add(key);
      m['time'] = time;
      out.add(m);
    }
    return out;
  }
}
