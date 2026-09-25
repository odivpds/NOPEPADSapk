import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'theme.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/login_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/note_editor_screen.dart';
import 'services/local_database_service.dart';
import 'widgets/neo_desktop_window_frame.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables for Supabase
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ?? '',
    // ignore: deprecated_member_use
    anonKey: dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ?? '',
  );

  // Initialize local SQLite database
  final localDb = LocalDatabaseService();
  await localDb.initDatabase();

  final prefs = await SharedPreferences.getInstance();
  
  // Check if this instance is a sub-window (Floating Note Editor)
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    try {
      await windowManager.ensureInitialized();
      final windowController = await WindowController.fromCurrentEngine();
      if (windowController.arguments.isNotEmpty) {
        final argument = jsonDecode(windowController.arguments) as Map<String, dynamic>;
        final noteId = argument['noteId'] as String?;
        final offsetX = (argument['offsetX'] as num?)?.toDouble() ?? 0.0;
        final offsetY = (argument['offsetY'] as num?)?.toDouble() ?? 0.0;
        if (noteId != null && noteId.isNotEmpty) {
          await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
          await windowManager.setSize(const Size(460, 520));
          await windowManager.setMinimumSize(const Size(360, 380));
          await windowManager.setTitle('NOPEPADS');
          if (offsetX > 0 || offsetY > 0) {
            try {
              final pos = await windowManager.getPosition();
              await windowManager.setPosition(Offset(pos.dx + offsetX, pos.dy + offsetY));
            } catch (_) {}
          }

          runApp(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                localDatabaseProvider.overrideWithValue(localDb),
              ],
              child: NoteEditorApp(
                windowId: windowController.windowId,
                noteId: noteId,
              ),
            ),
          );
          return;
        }
      }
    } catch (_) {}
  }

  if (args.firstOrNull == 'multi_window') {
    final windowId = args[1];
    final argument = args.length > 2 && args[2].isNotEmpty
        ? jsonDecode(args[2]) as Map<String, dynamic>
        : <String, dynamic>{};
    final noteId = argument['noteId'] as String?;
    final offsetX = (argument['offsetX'] as num?)?.toDouble() ?? 0.0;
    final offsetY = (argument['offsetY'] as num?)?.toDouble() ?? 0.0;

    if (noteId != null && noteId.isNotEmpty) {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        try {
          await windowManager.ensureInitialized();
          await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
          await windowManager.setSize(const Size(460, 520));
          await windowManager.setMinimumSize(const Size(360, 380));
          await windowManager.setTitle('NOPEPADS');
          if (offsetX > 0 || offsetY > 0) {
            try {
              final pos = await windowManager.getPosition();
              await windowManager.setPosition(Offset(pos.dx + offsetX, pos.dy + offsetY));
            } catch (_) {}
          }
        } catch (_) {}
      }

      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            localDatabaseProvider.overrideWithValue(localDb),
          ],
          child: NoteEditorApp(
            windowId: windowId,
            noteId: noteId,
          ),
        ),
      );
      return;
    }
  }

  // Configure desktop main window
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    try {
      await windowManager.ensureInitialized();
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
      await windowManager.setMinimumSize(const Size(720, 500));
      await windowManager.setTitle('NOPEPADS');
      await windowManager.setPreventClose(true);
    } catch (_) {}
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localDatabaseProvider.overrideWithValue(localDb),
      ],
      child: const NeoNotesApp(),
    ),
  );
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

class NeoNotesApp extends ConsumerWidget {
  const NeoNotesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    
    return MaterialApp(
      title: 'NOPEPADS',
      theme: NeoTheme.lightTheme,
      darkTheme: NeoTheme.darkTheme,
      themeMode: themeMode,
      // Always start at notes — login is optional
      initialRoute: '/notes',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/notes': (context) => const NotesScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/editor') {
          final noteId = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (context) => NoteEditorScreen(noteId: noteId),
          );
        }
        return null;
      },
      
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
      ],
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return NeoDesktopWindowFrame(
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
