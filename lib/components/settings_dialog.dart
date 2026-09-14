import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final user = Supabase.instance.client.auth.currentUser;

    return AlertDialog(
      title: const Text('Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account: ${user?.email ?? 'Unknown'}'),
          const SizedBox(height: 16),
          const Text('Theme'),
          RadioListTile<ThemeMode>(
            title: const Text('System'),
            value: ThemeMode.system,
            groupValue: themeMode,
            onChanged: (val) {
              if (val != null) ref.read(themeModeProvider.notifier).setThemeMode(val);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Light'),
            value: ThemeMode.light,
            groupValue: themeMode,
            onChanged: (val) {
              if (val != null) ref.read(themeModeProvider.notifier).setThemeMode(val);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark'),
            value: ThemeMode.dark,
            groupValue: themeMode,
            onChanged: (val) {
              if (val != null) ref.read(themeModeProvider.notifier).setThemeMode(val);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          },
          child: const Text('Log Out', style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
