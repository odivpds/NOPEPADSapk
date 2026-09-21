import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';
import 'services/multi_window_service.dart';

// Theme state management
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeModeNotifier(prefs);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences prefs;

  ThemeModeNotifier(this.prefs) : super(_loadThemeMode(prefs));

  static ThemeMode _loadThemeMode(SharedPreferences prefs) {
    final mode = prefs.getString('theme_mode');
    if (mode == 'dark') return ThemeMode.dark;
    if (mode == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }

  void toggle() {
    setThemeMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  void setThemeMode(ThemeMode mode, {bool broadcast = true}) {
    state = mode;
    prefs.setString('theme_mode', mode.name);
    if (broadcast) {
      MultiWindowService().broadcastThemeChanged(mode.name);
    }
  }
}

class NeoTheme {
  // MyNotes exact colors
  // Light: --bg-app: #FFF4E0, --bg-header: #E6B905, --note-default: #FFFFFF
  // Dark:  --bg-app: #1A1A24, --bg-header: #2E2E3A, --note-default: #2A2A35
  static const Color appBgLight = Color(0xFFFFF4E0);
  static const Color headerBgLight = Color(0xFFE6B905);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color primaryLight = Color(0xFF000000);

  static const Color appBgDark = Color(0xFF1A1A24);
  static const Color headerBgDark = Color(0xFF2E2E3A);
  static const Color cardDark = Color(0xFF2A2A35);
  static const Color primaryDark = Color(0xFFFFFFFF);

  // Font helper styles matching MyNotes exactly:
  // 1. Heading & Buttons: Comic Neue (--font-heading in MyNotes globals.css)
  static TextStyle headingFont({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w900,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    List<Shadow>? shadows,
  }) => GoogleFonts.comicNeue(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontStyle: fontStyle,
    shadows: shadows,
  );

  // 2. Sans / Body UI: Space Grotesk (--font-sans in MyNotes globals.css)
  static TextStyle sansFont({
    double? fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    List<Shadow>? shadows,
  }) => GoogleFonts.spaceGrotesk(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontStyle: fontStyle,
    shadows: shadows,
  );

  // 3. Pixel / Brand Title: Press Start 2P (--font-pixel in MyNotes globals.css)
  static TextStyle pixelFont({
    double? fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    List<Shadow>? shadows,
  }) => GoogleFonts.pressStart2p(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontStyle: fontStyle,
    shadows: shadows,
  );

  // 4. Monospace / Code: Space Mono (--font-mono in MyNotes globals.css)
  static TextStyle monoFont({
    double? fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    List<Shadow>? shadows,
  }) => GoogleFonts.spaceMono(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontStyle: fontStyle,
    shadows: shadows,
  );

  static TextTheme _buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;
    final spaceGroteskTheme = GoogleFonts.spaceGroteskTextTheme(base);

    return spaceGroteskTheme.copyWith(
      displayLarge: GoogleFonts.comicNeue(textStyle: spaceGroteskTheme.displayLarge, fontWeight: FontWeight.bold),
      displayMedium: GoogleFonts.comicNeue(textStyle: spaceGroteskTheme.displayMedium, fontWeight: FontWeight.bold),
      displaySmall: GoogleFonts.comicNeue(textStyle: spaceGroteskTheme.displaySmall, fontWeight: FontWeight.bold),
      headlineLarge: GoogleFonts.comicNeue(textStyle: spaceGroteskTheme.headlineLarge, fontWeight: FontWeight.bold),
      headlineMedium: GoogleFonts.comicNeue(textStyle: spaceGroteskTheme.headlineMedium, fontWeight: FontWeight.bold),
      headlineSmall: GoogleFonts.comicNeue(textStyle: spaceGroteskTheme.headlineSmall, fontWeight: FontWeight.bold),
      titleLarge: GoogleFonts.comicNeue(textStyle: spaceGroteskTheme.titleLarge, fontWeight: FontWeight.bold),
      titleMedium: GoogleFonts.comicNeue(textStyle: spaceGroteskTheme.titleMedium, fontWeight: FontWeight.bold),
      titleSmall: GoogleFonts.comicNeue(textStyle: spaceGroteskTheme.titleSmall, fontWeight: FontWeight.bold),
      labelLarge: GoogleFonts.comicNeue(textStyle: spaceGroteskTheme.labelLarge, fontWeight: FontWeight.bold),
    );
  }

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primaryLight,
      surface: cardLight,
    ),
    scaffoldBackgroundColor: appBgLight,
    textTheme: _buildTextTheme(Brightness.light),
    appBarTheme: const AppBarTheme(
      backgroundColor: headerBgLight,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: primaryDark,
      surface: cardDark,
    ),
    scaffoldBackgroundColor: appBgDark,
    textTheme: _buildTextTheme(Brightness.dark),
    appBarTheme: const AppBarTheme(
      backgroundColor: headerBgDark,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );
}

extension NeoThemeExtension on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Backgrounds matching MyNotes globals.css
  Color get neoAppBg => isDark ? const Color(0xFF1A1A24) : const Color(0xFFFFF4E0);
  Color get neoHeaderBg => isDark ? const Color(0xFF2E2E3A) : const Color(0xFFE6B905);
  Color get neoBackground => isDark ? const Color(0xFF1A1A24) : const Color(0xFFFFF4E0);
  Color get neoSidebar => isDark ? const Color(0xFF1A1A24) : const Color(0xFFFFF4E0);
  Color get neoCardBg => isDark ? const Color(0xFF2A2A35) : Colors.white;

  Color get neoText => isDark ? Colors.white : Colors.black;
  Color get neoTextMuted => isDark ? Colors.white70 : Colors.black54;
  Color get neoBorder => Colors.black;
  Color get neoBorder87 => Colors.black87;
  Color get neoShadow => Colors.black;
  Color get neoYellow => const Color(0xFFE6B905);
  Color get neoAction => isDark ? const Color(0xFF9B4F96) : const Color(0xFFFFB3C6);
}