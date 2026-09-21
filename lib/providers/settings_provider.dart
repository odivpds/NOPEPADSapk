import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // To access sharedPreferencesProvider

class SettingsState {
  final bool confirmBeforeDelete;
  final String userName;
  final String appTitle;

  SettingsState({
    required this.confirmBeforeDelete,
    required this.userName,
    required this.appTitle,
  });

  SettingsState copyWith({
    bool? confirmBeforeDelete,
    String? userName,
    String? appTitle,
  }) {
    return SettingsState(
      confirmBeforeDelete: confirmBeforeDelete ?? this.confirmBeforeDelete,
      userName: userName ?? this.userName,
      appTitle: appTitle ?? this.appTitle,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences prefs;

  SettingsNotifier(this.prefs) : super(_loadInitialState(prefs));

  static SettingsState _loadInitialState(SharedPreferences prefs) {
    return SettingsState(
      confirmBeforeDelete: prefs.getBool('confirmBeforeDelete') ?? true,
      userName: prefs.getString('userName') ?? 'EXPLORER',
      appTitle: prefs.getString('appTitle') ?? 'NOPEPADS',
    );
  }

  void toggleConfirmBeforeDelete(bool value) {
    prefs.setBool('confirmBeforeDelete', value);
    state = state.copyWith(confirmBeforeDelete: value);
  }

  void updateUserName(String name) {
    final value = name.trim().isEmpty ? 'EXPLORER' : name.toUpperCase();
    prefs.setString('userName', value);
    state = state.copyWith(userName: value);
  }

  void updateAppTitle(String title) {
    final value = title.trim().isEmpty ? 'NOPEPADS' : title.toUpperCase();
    prefs.setString('appTitle', value);
    state = state.copyWith(appTitle: value);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
