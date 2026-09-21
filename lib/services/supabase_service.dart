import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final notesCloudServiceProvider = Provider<NotesCloudService?>((ref) {
  final client = ref.watch(supabaseProvider);
  final user = client.auth.currentUser;
  if (user == null) return null; // Not logged in — no cloud service
  return NotesCloudService(client);
});

/// Cloud-only service for Supabase operations.
/// Used exclusively by SyncService — NOT directly from UI.
class NotesCloudService {
  final SupabaseClient _client;

  NotesCloudService(this._client);

  /// Returns null if user not logged in
  String? get userId => _client.auth.currentUser?.id;

  /// Check if user is authenticated
  bool get isLoggedIn => _client.auth.currentUser != null;

  // ========================
  // STANDARD CRUD (used by sync)
  // ========================

  Future<List<Note>> getNotes({String tab = 'active'}) async {
    var query = _client.from('notes').select().eq('user_id', userId!);
    
    if (tab == 'archive') {
      query = query.eq('is_deleted', false).eq('is_archived', true);
    } else if (tab == 'trash') {
      query = query.eq('is_deleted', true);
    } else {
      query = query.eq('is_deleted', false).eq('is_archived', false);
    }

    final response = await query.order('updated_at', ascending: false);
    return response.map<Note>((json) => Note.fromJson(json)).toList();
  }

  Future<Note?> getNoteById(String noteId) async {
    final response = await _client
        .from('notes')
        .select()
        .eq('id', noteId)
        .eq('user_id', userId!)
        .maybeSingle();
        
    if (response == null) return null;
    return Note.fromJson(response);
  }

  Future<void> createNote(Note note) async {
    await _client.from('notes').insert(note.toJson());
  }

  Future<void> updateNote(Note note) async {
    await _client
        .from('notes')
        .update(note.toJson())
        .eq('id', note.id)
        .eq('user_id', userId!);
  }

  Future<void> moveNoteToTrash(String noteId) async {
    await _client
        .from('notes')
        .update({
          'is_deleted': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', noteId)
        .eq('user_id', userId!);
  }

  Future<void> deleteNotePermanently(String noteId) async {
    await _client
        .from('notes')
        .delete()
        .eq('id', noteId)
        .eq('user_id', userId!);
  }

  Future<void> togglePin(String noteId, bool isPinned) async {
    await _client
        .from('notes')
        .update({
          'is_pinned': isPinned,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', noteId)
        .eq('user_id', userId!);
  }

  Future<void> toggleArchive(String noteId, bool isArchived) async {
    await _client
        .from('notes')
        .update({
          'is_archived': isArchived,
          'is_pinned': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', noteId)
        .eq('user_id', userId!);
  }

  Future<void> restoreNote(String noteId) async {
    await _client
        .from('notes')
        .update({
          'is_deleted': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', noteId)
        .eq('user_id', userId!);
  }

  // ========================
  // SYNC-SPECIFIC METHODS
  // ========================

  /// Get ALL notes for sync (including deleted/archived)
  Future<List<Note>> getAllNotesForSync() async {
    final response = await _client
        .from('notes')
        .select()
        .eq('user_id', userId!)
        .order('updated_at', ascending: false);
    return response.map<Note>((json) => Note.fromJson(json)).toList();
  }

  /// Upsert a note (insert or update based on conflict)
  Future<void> upsertNote(Note note) async {
    await _client.from('notes').upsert(note.toJson());
  }
}
