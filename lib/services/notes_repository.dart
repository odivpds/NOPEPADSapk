import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note.dart';
import 'local_database_service.dart';
import 'sync_service.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final localDb = ref.watch(localDatabaseProvider);
  final syncService = ref.watch(syncServiceProvider);
  return NotesRepository(localDb, syncService);
});

/// Smart router: all operations go to local DB first,
/// then sync to cloud in background if possible.
class NotesRepository {
  final LocalDatabaseService _localDb;
  final SyncService _syncService;

  NotesRepository(this._localDb, this._syncService);

  /// Get the current user ID (from Supabase auth, or 'local' if not logged in)
  String get currentUserId {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.id ?? 'local';
  }

  /// Whether the user is logged in
  bool get isLoggedIn => Supabase.instance.client.auth.currentUser != null;

  // ========================
  // NOTES CRUD — Local-first
  // ========================

  /// Get notes for the current user and tab
  Future<List<Note>> getNotes({String tab = 'active'}) async {
    return _localDb.getNotes(userId: currentUserId, tab: tab);
  }

  /// Get a single note by ID
  Future<Note?> getNoteById(String noteId) async {
    return _localDb.getNoteById(noteId);
  }

  /// Create a new note — saves to local DB instantly, syncs in background
  Future<void> createNote(Note note) async {
    // Ensure note has correct user_id
    final noteWithUser = note.copyWith(
      userId: currentUserId,
      isSynced: false,
    );

    await _localDb.insertNote(noteWithUser);
    await _localDb.addToSyncQueue(noteWithUser.id, 'create');
    _syncService.trySyncInBackground();
  }

  /// Update an existing note — saves to local DB instantly, syncs in background
  Future<void> updateNote(Note note) async {
    final updatedNote = note.copyWith(isSynced: false);
    await _localDb.updateNote(updatedNote);
    await _localDb.addToSyncQueue(updatedNote.id, 'update');
    _syncService.trySyncInBackground();
  }

  /// Move note to trash — local first, then sync
  Future<void> moveNoteToTrash(String noteId) async {
    await _localDb.softDeleteNote(noteId);
    await _localDb.addToSyncQueue(noteId, 'update');
    _syncService.trySyncInBackground();
  }

  /// Permanently delete a note — local first, then sync
  Future<void> deleteNotePermanently(String noteId) async {
    await _localDb.deleteNotePermanently(noteId);
    await _localDb.addToSyncQueue(noteId, 'delete_permanent');
    _syncService.trySyncInBackground();
  }

  /// Toggle pin — local first, then sync
  Future<void> togglePin(String noteId, bool isPinned) async {
    await _localDb.togglePin(noteId, isPinned);
    await _localDb.addToSyncQueue(noteId, 'update');
    _syncService.trySyncInBackground();
  }

  /// Toggle archive — local first, then sync
  Future<void> toggleArchive(String noteId, bool isArchived) async {
    await _localDb.toggleArchive(noteId, isArchived);
    await _localDb.addToSyncQueue(noteId, 'update');
    _syncService.trySyncInBackground();
  }

  /// Restore from trash — local first, then sync
  Future<void> restoreNote(String noteId) async {
    await _localDb.restoreNote(noteId);
    await _localDb.addToSyncQueue(noteId, 'update');
    _syncService.trySyncInBackground();
  }

  /// Force a full sync now
  Future<void> syncNow() async {
    await _syncService.syncAll();
  }

  /// Merge local notes after login
  Future<void> mergeAfterLogin() async {
    await _syncService.mergeAfterLogin(currentUserId);
  }
}
