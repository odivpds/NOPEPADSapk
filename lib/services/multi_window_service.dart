import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';

final multiWindowServiceProvider = Provider<MultiWindowService>((ref) {
  return MultiWindowService();
});

const _channel = WindowMethodChannel(
  'nopepads_events',
  mode: ChannelMode.bidirectional,
);

class MultiWindowService {
  static final MultiWindowService _instance = MultiWindowService._internal();
  factory MultiWindowService() => _instance;
  MultiWindowService._internal();

  /// Map of noteId -> windowId
  final Map<String, String> _openWindows = {};

  bool get isDesktopPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  bool get hasOpenStickyNotes => _openWindows.isNotEmpty;

  bool isMainWindowHidden = false;

  /// Check active sticky notes count by checking registered window controllers
  Future<bool> checkHasOpenStickyNotes() async {
    if (!isDesktopPlatform) return false;
    if (_openWindows.isEmpty) return false;
    try {
      final allWindows = await WindowController.getAll();
      final activeIds = allWindows.map((w) => w.windowId).toSet();
      _openWindows.removeWhere((noteId, winId) => !activeIds.contains(winId));
      return _openWindows.isNotEmpty;
    } catch (_) {
      return _openWindows.isNotEmpty;
    }
  }

  /// Open or focus a sticky note window for the given noteId
  Future<void> openStickyNote(String noteId, {String? title}) async {
    if (!isDesktopPlatform) return;

    if (_openWindows.containsKey(noteId)) {
      final existingWindowId = _openWindows[noteId]!;
      try {
        final allWindows = await WindowController.getAll();
        final match = allWindows.any((w) => w.windowId == existingWindowId);
        if (match) {
          final controller = WindowController.fromWindowId(existingWindowId);
          await controller.show();
          return;
        } else {
          _openWindows.remove(noteId);
        }
      } catch (_) {
        _openWindows.remove(noteId);
      }
    }

    try {
      final controller = await WindowController.create(
        WindowConfiguration(
          arguments: jsonEncode({
            'noteId': noteId,
          }),
          hiddenAtLaunch: true,
        ),
      );

      _openWindows[noteId] = controller.windowId;
      // Sub-window will configure itself (frameless, size, dark bg) and reveal itself on first frame
    } catch (e) {
      debugPrint('Error creating sticky note window: $e');
    }
  }

  /// Initialize listener in the Main Window to receive updates from sticky note windows
  void initMainWindowListener({
    required VoidCallback onNotesRefresh,
    VoidCallback? onCreateNote,
  }) {
    if (!isDesktopPlatform) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'noteChanged' || call.method == 'refreshNotes') {
        // Only refresh UI if main window is actually visible to avoid background lag
        if (!isMainWindowHidden) {
          onNotesRefresh();
        }
      } else if (call.method == 'showMainWindow') {
        isMainWindowHidden = false;
        try {
          await windowManager.show();
          await windowManager.focus();
        } catch (_) {}
        onNotesRefresh();
      } else if (call.method == 'createNewNote') {
        onCreateNote?.call();
      } else if (call.method == 'windowClosed') {
        final noteId = call.arguments as String?;
        if (noteId != null) {
          _openWindows.remove(noteId);
        }
        if (isMainWindowHidden) {
          // Allow the closing sub-window to cleanly finish its window teardown before exiting
          Future.delayed(const Duration(milliseconds: 300), () async {
            if (isMainWindowHidden) {
              final hasActive = await checkHasOpenStickyNotes();
              if (!hasActive && isMainWindowHidden) {
                exit(0);
              }
            }
          });
        }
      }
      return null;
    });
  }

  /// Notify the main window that a note was changed
  static Future<void> notifyMainWindowNoteChanged(String noteId) async {
    if (kIsWeb || (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) return;
    try {
      await _channel.invokeMethod('noteChanged', noteId).catchError((_) => null);
    } catch (_) {}
  }

  /// Notify the main window that a sticky note window was closed
  static Future<void> notifyMainWindowClosed(String noteId) async {
    if (kIsWeb || (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) return;
    try {
      await _channel.invokeMethod('windowClosed', noteId).catchError((_) => null);
    } catch (_) {}
  }

  /// Request main window to unhide and focus itself
  static Future<void> showMainWindow() async {
    if (kIsWeb || (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) return;
    try {
      await _channel.invokeMethod('showMainWindow').catchError((_) => null);
    } catch (_) {}
  }

  /// Request main window to create a new note and open its window
  static Future<void> createNewNoteFromSubWindow() async {
    if (kIsWeb || (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) return;
    try {
      await _channel.invokeMethod('createNewNote').catchError((_) => null);
    } catch (_) {}
  }

  /// Broadcast theme changes from main window to all active floating sticky notes
  Future<void> broadcastThemeChanged(String themeModeName) async {
    if (!isDesktopPlatform) return;
    if (_openWindows.isEmpty) return;
    try {
      await _channel.invokeMethod('themeChanged', themeModeName).catchError((_) => null);
    } catch (_) {}
    for (final windowId in _openWindows.values) {
      try {
        final controller = WindowController.fromWindowId(windowId);
        await controller.invokeMethod('themeChanged', themeModeName).catchError((_) => null);
      } catch (_) {}
    }
  }

  /// Initialize listener in a Sub-Window (Sticky Note) to receive updates like theme changes
  static void initSubWindowListener({
    required void Function(String themeModeName) onThemeChanged,
  }) {
    if (kIsWeb || (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'themeChanged') {
        final modeName = call.arguments as String?;
        if (modeName != null) {
          onThemeChanged(modeName);
        }
      }
      return null;
    });
  }
}
