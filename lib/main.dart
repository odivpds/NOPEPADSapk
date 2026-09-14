import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/note_editor_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables for Supabase
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ?? '',
  );

  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
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
      initialRoute: Supabase.instance.client.auth.currentUser != null ? '/notes' : '/login',
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

    );
  }
}
