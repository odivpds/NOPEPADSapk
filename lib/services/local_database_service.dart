import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import '../models/note.dart';

/// Provider for LocalDatabaseService — overridden in main.dart with initialized instance
final localDatabaseProvider = Provider<LocalDatabaseService>((ref) {
  throw UnimplementedError('localDatabaseProvider must be overridden');
});

class LocalDatabaseService {
  Database? _db;

  Database get db {
    if (_db == null) throw StateError('Database not initialized. Call initDatabase() first.');
    return _db!;
  }

  bool get isInitialized => _db != null;

  /// Initialize SQLite database and create tables
  Future<void> initDatabase() async {
    // On desktop platforms (Windows, Linux, macOS), initialize FFI
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'nopepads.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL DEFAULT 'local',
            title TEXT NOT NULL DEFAULT '',
            content TEXT,
            color TEXT NOT NULL DEFAULT 'Yellow',
            is_pinned INTEGER NOT NULL DEFAULT 0,
            is_archived INTEGER NOT NULL DEFAULT 0,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_synced INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            note_id TEXT NOT NULL,
            action TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        // Index for common queries
        await db.execute('CREATE INDEX idx_notes_user_id ON notes(user_id)');
        await db.execute('CREATE INDEX idx_notes_updated_at ON notes(updated_at)');
        await db.execute('CREATE INDEX idx_sync_queue_note_id ON sync_queue(note_id)');
      },
    );

    // Enable WAL mode and busy timeout for concurrent multi-window database access
    try {
      await _db!.execute('PRAGMA journal_mode=WAL;');
      await _db!.execute('PRAGMA busy_timeout=5000;');
    } catch (_) {}
  }

  // ========================
  // NOTES CRUD
  // ========================

  /// Get all notes for a specific user and tab
  Future<List<Note>> getNotes({
    required String userId,
    String tab = 'active',
  }) async {
    String where;
    List<dynamic> whereArgs;

    if (tab == 'archive') {
      where = 'user_id = ? AND is_deleted = 0 AND is_archived = 1';
      whereArgs = [userId];
    } else if (tab == 'trash') {
      where = 'user_id = ? AND is_deleted = 1';
      whereArgs = [userId];
    } else {
      where = 'user_id = ? AND is_deleted = 0 AND is_archived = 0';
      whereArgs = [userId];
    }

    final rows = await db.query(
      'notes',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
    );

    return rows.map((row) => Note.fromSqlite(row)).toList();
  }

  /// Get a single note by ID
  Future<Note?> getNoteById(String noteId) async {
    final rows = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [noteId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return Note.fromSqlite(rows.first);
  }

  Map<String, dynamic> _serializeNoteForSqlite(Note note) {
    final map = note.toSqlite();
    if (map['content'] != null && map['content'] is! String) {
      map['content'] = jsonEncode(map['content']);
    }
    return map;
  }

  /// Insert a new note
  Future<void> insertNote(Note note) async {
    await db.insert(
      'notes',
      _serializeNoteForSqlite(note),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing note
  Future<void> updateNote(Note note) async {
    await db.update(
      'notes',
      _serializeNoteForSqlite(note),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  /// Soft-delete (move to trash)
  Future<void> softDeleteNote(String noteId) async {
    await db.update(
      'notes',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  /// Permanently delete a note
  Future<void> deleteNotePermanently(String noteId) async {
    await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  /// Toggle pin status
  Future<void> togglePin(String noteId, bool isPinned) async {
    await db.update(
      'notes',
      {
        'is_pinned': isPinned ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  /// Toggle archive status
  Future<void> toggleArchive(String noteId, bool isArchived) async {
    await db.update(
      'notes',
      {
        'is_archived': isArchived ? 1 : 0,
        'is_pinned': 0,
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  /// Restore note from trash
  Future<void> restoreNote(String noteId) async {
    await db.update(
      'notes',
      {
        'is_deleted': 0,
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  /// Get all notes for a user (including deleted) — used by sync
  Future<List<Note>> getAllNotesForSync(String userId) async {
    final rows = await db.query(
      'notes',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows.map((row) => Note.fromSqlite(row)).toList();
  }

  /// Get unsynced notes
  Future<List<Note>> getUnsyncedNotes(String userId) async {
    final rows = await db.query(
      'notes',
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );
    return rows.map((row) => Note.fromSqlite(row)).toList();
  }

  /// Mark note as synced
  Future<void> markAsSynced(String noteId) async {
    await db.update(
      'notes',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  /// Migrate local notes to a user account (after login)
  Future<void> migrateLocalNotesToUser(String newUserId) async {
    await db.update(
      'notes',
      {
        'user_id': newUserId,
        'is_synced': 0,
      },
      where: 'user_id = ?',
      whereArgs: ['local'],
    );
  }

  /// Get notes belonging to 'local' user (unsigned notes)
  Future<List<Note>> getLocalUnsignedNotes() async {
    final rows = await db.query(
      'notes',
      where: 'user_id = ?',
      whereArgs: ['local'],
    );
    return rows.map((row) => Note.fromSqlite(row)).toList();
  }

  // ========================
  // SYNC QUEUE
  // ========================

  /// Add an action to the sync queue
  Future<void> addToSyncQueue(String noteId, String action) async {
    // Remove previous pending actions for same note to avoid duplicates
    await db.delete(
      'sync_queue',
      where: 'note_id = ?',
      whereArgs: [noteId],
    );

    await db.insert('sync_queue', {
      'note_id': noteId,
      'action': action,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get all pending sync actions
  Future<List<Map<String, dynamic>>> getPendingSyncActions() async {
    return await db.query(
      'sync_queue',
      orderBy: 'created_at ASC',
    );
  }

  /// Remove a sync action after successful sync
  Future<void> removeSyncAction(int id) async {
    await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Clear all sync queue entries
  Future<void> clearSyncQueue() async {
    await db.delete('sync_queue');
  }

  /// Clear all local data (used on explicit "clear data" action)
  Future<void> clearAllData() async {
    await db.delete('notes');
    await db.delete('sync_queue');
  }
}
