import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note.dart';
import '../models/tag.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final notesServiceProvider = Provider<NotesService>((ref) {
  final client = ref.watch(supabaseProvider);
  return NotesService(client);
});

class NotesService {
  final SupabaseClient _client;

  NotesService(this._client);

  String get userId => _client.auth.currentUser!.id;

    Future<List<Note>> getNotes() async {
    final response = await _client
        .from('notes')
        .select()
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .order('updated_at', ascending: false);
    return response.map<Note>((json) => Note.fromJson(json)).toList();
  }

  Stream<List<Note>> getNotesStream() {
    return _client
        .from('notes')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .order('updated_at', ascending: false)
        .map((data) => data.map((json) => Note.fromJson(json)).toList());
  }

  Future<void> createNote(Note note) async {
    await _client.from('notes').insert(note.toJson());
  }

  Future<void> updateNote(Note note) async {
    await _client
        .from('notes')
        .update(note.toJson())
        .eq('id', note.id)
        .eq('user_id', userId);
  }

  Future<void> moveNoteToTrash(String noteId) async {
    await _client
        .from('notes')
        .update({
          'is_deleted': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', noteId)
        .eq('user_id', userId);
  }

  Future<void> deleteNotePermanently(String noteId) async {
    await _client
        .from('notes')
        .delete()
        .eq('id', noteId)
        .eq('user_id', userId);
  }

  Future<Note?> getNoteById(String noteId) async {
    final response = await _client
        .from('notes')
        .select()
        .eq('id', noteId)
        .eq('user_id', userId)
        .maybeSingle();
        
    if (response == null) return null;
    return Note.fromJson(response);
  }
}

