import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/settings_provider.dart';
import '../services/notes_repository.dart';
import '../services/sync_service.dart';
import '../theme.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  final VoidCallback? onReplayTour;

  const SettingsDialog({super.key, this.onReplayTour});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  bool _isUpdatingPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  String? _passwordMessage;
  bool _passwordSuccess = false;
  bool _isManualSyncing = false;

  final _nameController = TextEditingController();
  final _appTitleController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(settingsProvider);
      _nameController.text = state.userName;
      _appTitleController.text = state.appTitle;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _appTitleController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleManualSync() async {
    setState(() => _isManualSyncing = true);
    try {
      await ref.read(notesRepositoryProvider).syncNow();
      if (mounted) {
        _showSnackBar('Sync completed successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Sync error: $e');
      }
    } finally {
      if (mounted) setState(() => _isManualSyncing = false);
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar('Signed out. Using offline mode.');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error signing out: $e');
      }
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed('/login');
  }

  Future<void> _handleUpdatePassword() async {
    setState(() {
      _passwordMessage = null;
    });

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _passwordMessage = 'Passwords do not match!';
        _passwordSuccess = false;
      });
      return;
    }
    if (_newPasswordController.text.length < 6) {
      setState(() {
        _passwordMessage = 'Password must be at least 6 characters.';
        _passwordSuccess = false;
      });
      return;
    }

    setState(() => _isUpdatingPassword = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );
      if (mounted) {
        setState(() {
          _passwordMessage = 'Password updated successfully!';
          _passwordSuccess = true;
        });
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _passwordMessage = null);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _passwordMessage = 'Error: ${e.toString()}';
          _passwordSuccess = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isUpdatingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final isLoggedIn = user != null;
    final syncStatus = ref.watch(syncStatusProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 450,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: context.neoAppBg,
          border: Border.all(color: Colors.black, width: 4),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(8, 8))],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black, width: 4)),
                ),
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SETTINGS',
                      style: NeoTheme.headingFont(
                        color: context.neoText,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLoggedIn ? Colors.greenAccent : const Color(0xFFE6B905),
                        border: Border.all(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                      ),
                      child: Text(
                        isLoggedIn ? 'ONLINE' : 'OFFLINE',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Color Theme
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Color Theme',
                          style: NeoTheme.headingFont(
                            color: context.neoText,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Light or Dark mode',
                          style: NeoTheme.sansFont(color: context.neoTextMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _ThemeToggleSegment(
                    isDark: context.isDark,
                    onToggle: () {
                      ref.read(themeModeProvider.notifier).toggle();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionDivider(),

              // Confirm before deleting
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Confirm before deleting',
                          style: NeoTheme.headingFont(
                            color: context.neoText,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Show a popup before deleting a note',
                          style: NeoTheme.sansFont(color: context.neoTextMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => ref
                          .read(settingsProvider.notifier)
                          .toggleConfirmBeforeDelete(!settings.confirmBeforeDelete),
                      child: Container(
                        width: 56,
                        height: 32,
                        decoration: BoxDecoration(
                          color: settings.confirmBeforeDelete ? Colors.green : Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: settings.confirmBeforeDelete
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 20,
                            height: 20,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _buildSectionDivider(),

              // Your Name
              Text(
                'Your Name',
                style: NeoTheme.headingFont(
                  color: context.neoText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Change your display name',
                style: NeoTheme.sansFont(color: context.neoTextMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(_nameController, 'Enter name...'),
                  ),
                  const SizedBox(width: 8),
                  _buildSaveButton(onTap: () {
                    if (_nameController.text.trim().isNotEmpty) {
                      ref.read(settingsProvider.notifier).updateUserName(_nameController.text.trim());
                      _showSnackBar('Name saved!');
                    }
                  }),
                ],
              ),

              const SizedBox(height: 24),
              _buildSectionDivider(),

              // App Title
              Text(
                'App Title',
                style: NeoTheme.headingFont(
                  color: context.neoText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Custom name in the top header',
                style: NeoTheme.sansFont(color: context.neoTextMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(_appTitleController, 'Enter title...'),
                  ),
                  const SizedBox(width: 8),
                  _buildSaveButton(onTap: () {
                    if (_appTitleController.text.trim().isNotEmpty) {
                      ref.read(settingsProvider.notifier).updateAppTitle(_appTitleController.text.trim());
                      _showSnackBar('Title saved!');
                    }
                  }),
                ],
              ),

              const SizedBox(height: 24),
              _buildSectionDivider(),

              // Cloud Sync & Account Section
              Text(
                'Cloud Sync & Account',
                style: NeoTheme.headingFont(
                  color: context.neoText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isLoggedIn
                    ? 'Sync notes with cloud and across devices'
                    : 'Log in to backup & sync notes to the cloud',
                style: NeoTheme.sansFont(color: context.neoTextMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),

              if (isLoggedIn) ...[
                // Logged in user details & sync controls
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.isDark ? const Color(0xFF27272A) : Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_circle, size: 20, color: Colors.blueAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              user.email ?? 'Logged in',
                              style: NeoTheme.sansFont(
                                color: context.neoText,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildSyncStatusBadge(syncStatus),
                          const Spacer(),
                          // Sync Now button
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: (_isManualSyncing || syncStatus == SyncStatus.syncing)
                                  ? null
                                  : _handleManualSync,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6B905),
                                  border: Border.all(color: Colors.black, width: 2),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.sync,
                                      size: 16,
                                      color: Colors.black,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isManualSyncing ? 'SYNCING...' : 'SYNC NOW',
                                      style: NeoTheme.headingFont(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Sign Out Button
                Align(
                  alignment: Alignment.centerRight,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _handleSignOut,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          border: Border.all(color: Colors.black, width: 2),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                        ),
                        child: Text(
                          'SIGN OUT',
                          style: NeoTheme.headingFont(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Offline mode promo card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.isDark ? const Color(0xFF27272A) : Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.offline_pin, color: Color(0xFFE6B905), size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Local Storage Active',
                              style: NeoTheme.headingFont(
                                color: context.neoText,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'All notes are safely saved in your local SQLite database on this device. Sign in anytime to sync to the cloud.',
                        style: NeoTheme.sansFont(color: context.neoTextMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _navigateToLogin,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6B905),
                              border: Border.all(color: Colors.black, width: 2),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cloud_upload_outlined, color: Colors.black, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'LOG IN TO SYNC',
                                  style: NeoTheme.headingFont(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Change Password (only available when logged in)
              if (isLoggedIn) ...[
                const SizedBox(height: 24),
                _buildSectionDivider(),
                Text(
                  'Change Password',
                  style: NeoTheme.headingFont(
                    color: context.neoText,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Update your account password',
                  style: NeoTheme.sansFont(color: context.neoTextMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),

                // New Password Field
                Text(
                  'New Password',
                  style: NeoTheme.sansFont(
                    color: context.neoText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                _buildPasswordField(
                  controller: _newPasswordController,
                  showPassword: _showNewPassword,
                  onToggleShow: () => setState(() => _showNewPassword = !_showNewPassword),
                  hintText: 'Enter new password...',
                ),
                const SizedBox(height: 12),

                // Confirm Password Field
                Text(
                  'Confirm Password',
                  style: NeoTheme.sansFont(
                    color: context.neoText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  showPassword: _showConfirmPassword,
                  onToggleShow: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                  hintText: 'Confirm new password...',
                ),
                const SizedBox(height: 12),

                if (_passwordMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      _passwordMessage!,
                      style: NeoTheme.sansFont(
                        color: _passwordSuccess ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),

                // Update Password Button
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _isUpdatingPassword ? null : _handleUpdatePassword,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6B905),
                        border: Border.all(color: Colors.black, width: 3),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _isUpdatingPassword ? 'UPDATING...' : 'UPDATE PASSWORD',
                        style: NeoTheme.headingFont(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              _buildSectionDivider(),

              // Onboarding Tour
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replay Onboarding Tour',
                          style: NeoTheme.sansFont(
                            color: context.neoText,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Show the welcome tips again',
                          style: NeoTheme.sansFont(color: context.neoTextMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onReplayTour?.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.isDark ? const Color(0xFF27272A) : Colors.white,
                          border: Border.all(color: Colors.black, width: 2),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                        ),
                        child: Text(
                          'REPLAY TOUR',
                          style: NeoTheme.headingFont(
                            color: context.neoText,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Done Button
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6B905),
                      border: Border.all(color: Colors.black, width: 3),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'DONE',
                      style: NeoTheme.headingFont(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncStatusBadge(SyncStatus status) {
    IconData icon;
    Color color;
    String label;

    switch (status) {
      case SyncStatus.synced:
        icon = Icons.cloud_done;
        color = Colors.green;
        label = 'Synced';
        break;
      case SyncStatus.syncing:
        icon = Icons.sync;
        color = Colors.blue;
        label = 'Syncing...';
        break;
      case SyncStatus.offline:
        icon = Icons.cloud_off;
        color = Colors.orange;
        label = 'Offline';
        break;
      case SyncStatus.error:
        icon = Icons.error_outline;
        color = Colors.red;
        label = 'Sync error';
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: NeoTheme.sansFont(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionDivider() {
    return Container(
      height: 2,
      color: Colors.black,
      margin: const EdgeInsets.only(bottom: 20),
    );
  }

  Widget _buildInputField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF27272A) : Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
      ),
      child: TextField(
        controller: controller,
        style: NeoTheme.sansFont(
          color: context.neoText,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: NeoTheme.sansFont(color: context.neoTextMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool showPassword,
    required VoidCallback onToggleShow,
    required String hintText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF27272A) : Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: !showPassword,
              style: NeoTheme.sansFont(
                color: context.neoText,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: NeoTheme.sansFont(color: context.neoTextMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onToggleShow,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  showPassword ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: context.neoText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton({required VoidCallback onTap}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE6B905),
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
          ),
          child: Text(
            'SAVE',
            style: NeoTheme.headingFont(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: NeoTheme.sansFont(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFE6B905),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ThemeToggleSegment extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;

  const _ThemeToggleSegment({required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFE5E7EB),
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(
            icon: Icons.light_mode,
            label: 'LIGHT',
            isSelected: !isDark,
            activeColor: const Color(0xFFE6B905),
            activeFg: Colors.black,
            onTap: isDark ? onToggle : null,
          ),
          const SizedBox(width: 4),
          _buildOption(
            icon: Icons.dark_mode,
            label: 'DARK',
            isSelected: isDark,
            activeColor: const Color(0xFF6366F1),
            activeFg: Colors.white,
            onTap: !isDark ? onToggle : null,
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color activeColor,
    required Color activeFg,
    required VoidCallback? onTap,
  }) {
    return MouseRegion(
      cursor: isSelected ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isSelected ? Border.all(color: Colors.black, width: 1.5) : null,
            boxShadow: isSelected
                ? const [BoxShadow(color: Colors.black, offset: Offset(1, 1))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: isSelected ? activeFg : Colors.grey),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: isSelected ? activeFg : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}