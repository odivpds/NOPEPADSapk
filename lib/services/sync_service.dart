import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_database_service.dart';
import 'supabase_service.dart';
import 'connectivity_service.dart';

/// Sync status for UI display
enum SyncStatus { synced, syncing, offline, error }

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.synced);

final syncServiceProvider = Provider<SyncService>((ref) {
  final localDb = ref.watch(localDatabaseProvider);
  final cloudService = ref.watch(notesCloudServiceProvider);
  return SyncService(localDb, cloudService, ref);
});

class SyncService {
  final LocalDatabaseService _localDb;
  final NotesCloudService? _cloudService;
  final Ref _ref;
  bool _isSyncing = false;

  SyncService(this._localDb, this._cloudService, this._ref);

  bool get canSync => _cloudService != null && _cloudService.isLoggedIn;

  /// Try sync in background — won't throw, safe to call anytime
  Future<void> trySyncInBackground() async {
    if (!canSync || _isSyncing) return;

    // Check connectivity
    try {
      final isOnline = await ConnectivityService().checkOnline();
      if (!isOnline) {
        _ref.read(syncStatusProvider.notifier).state = SyncStatus.offline;
        return;
      }
    } catch (_) {
      // Don't mark offline on check error, attempt actual sync
    }

    await syncAll();
  }

  /// Full sync: push local changes → pull cloud changes
  Future<void> syncAll() async {
    if (!canSync || _isSyncing) return;
    _isSyncing = true;
    _ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;

    try {
      await _pushLocalChanges();
      await _pullCloudChanges();
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.synced;
    } catch (e) {
      debugPrint('SyncService error: $e');
      final err = e.toString().toLowerCase();
      if (err.contains('socketexception') ||
          err.contains('failed host lookup') ||
          err.contains('network is unreachable') ||
          err.contains('clientexception')) {
        _ref.read(syncStatusProvider.notifier).state = SyncStatus.offline;
      } else {
        _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Push unsynced local notes to cloud
  Future<void> _pushLocalChanges() async {
    if (_cloudService == null) return;
    final userId = _cloudService.userId;
    if (userId == null) return;

    final unsyncedNotes = await _localDb.getUnsyncedNotes(userId);

    for (final note in unsyncedNotes) {
      try {
        // Check if note exists in cloud
        final cloudNote = await _cloudService.getNoteById(note.id);

        if (cloudNote == null) {
          // Note doesn't exist in cloud — push it
          await _cloudService.upsertNote(note);
        } else {
          // Conflict resolution: last-write-wins
          if (note.updatedAt.isAfter(cloudNote.updatedAt)) {
            await _cloudService.upsertNote(note);
          }
          // If cloud is newer, pull will handle it
        }

        await _localDb.markAsSynced(note.id);
      } catch (e) {
        debugPrint('Failed to push note ${note.id}: $e');
        // Continue with other notes
      }
    }

    // Process sync queue for permanent deletes
    final pendingActions = await _localDb.getPendingSyncActions();
    for (final action in pendingActions) {
      try {
        if (action['action'] == 'delete_permanent') {
          await _cloudService.deleteNotePermanently(action['note_id'] as String);
        }
        await _localDb.removeSyncAction(action['id'] as int);
      } catch (e) {
        debugPrint('Failed to process sync action: $e');
      }
    }
  }

  /// Pull cloud notes and merge into local database
  Future<void> _pullCloudChanges() async {
    if (_cloudService == null) return;

    final cloudNotes = await _cloudService.getAllNotesForSync();

    for (final cloudNote in cloudNotes) {
      try {
        final localNote = await _localDb.getNoteById(cloudNote.id);

        if (localNote == null) {
          // New note from cloud — insert locally
          await _localDb.insertNote(cloudNote.copyWith(isSynced: true));
        } else {
          // Conflict resolution: last-write-wins
          if (cloudNote.updatedAt.isAfter(localNote.updatedAt)) {
            await _localDb.updateNote(cloudNote.copyWith(isSynced: true));
          }
          // If local is newer, it was already pushed (or will be)
        }
      } catch (e) {
        debugPrint('Failed to pull note ${cloudNote.id}: $e');
      }
    }
  }

  /// Merge local unsigned notes into cloud after first login
  Future<void> mergeAfterLogin(String newUserId) async {
    // 1. Migrate local notes (user_id='local') to the new user account
    final localNotes = await _localDb.getLocalUnsignedNotes();
    if (localNotes.isNotEmpty) {
      await _localDb.migrateLocalNotesToUser(newUserId);
    }

    // 2. Full sync to push migrated notes and pull existing cloud notes
    await syncAll();
  }

  /// Queue a note action for sync
  Future<void> queueChange(String noteId, String action) async {
    await _localDb.addToSyncQueue(noteId, action);
  }
}
