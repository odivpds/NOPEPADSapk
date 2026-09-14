import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'neo_box.dart';
import 'neo_button.dart';
import 'neo_text_field.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  bool _confirmBeforeDeleting = true;
  final _nameController = TextEditingController(text: 'prana');
  final _appTitleController = TextEditingController(text: 'prana');
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: NeoBox(
        backgroundColor: const Color(0xFF27272A),
        width: 450,
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white, width: 2)),
                ),
                padding: const EdgeInsets.only(bottom: 8),
                child: const Text(
                  'SETTINGS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Confirm before deleting
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Confirm before deleting', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Show a popup before deleting a note', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _confirmBeforeDeleting,
                    onChanged: (val) => setState(() => _confirmBeforeDeleting = val),
                    activeColor: Colors.white,
                    activeTrackColor: Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Your Name
              const Text('Your Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Text('Customize the name used in the motivational quotes', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF18181B),
                        border: Border.all(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 40,
                    child: NeoButton(
                      text: 'SAVE',
                      height: 40,
                      onPressed: () {},
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),
              // Nopepads Name
              const Text('Nopepads Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Text('Customize the app title (e.g. type "ODIV" for "ODIV\'S NOPEPADS")', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF18181B),
                        border: Border.all(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _appTitleController,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 40,
                    child: NeoButton(
                      text: 'SAVE',
                      height: 40,
                      onPressed: () {},
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),
              // Change Password
              const Text('Change Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Text('Update your account password', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: 'New Password',
                    hintStyle: TextStyle(color: Colors.white54),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: InputBorder.none,
                    suffixIcon: Icon(Icons.visibility_off, color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: 'Confirm New Password',
                    hintStyle: TextStyle(color: Colors.white54),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: InputBorder.none,
                    suffixIcon: Icon(Icons.visibility_off, color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              NeoButton(
                text: 'UPDATE PASSWORD',
                height: 40,
                backgroundColor: Colors.grey.shade400,
                onPressed: () {},
              ),
              const SizedBox(height: 32),
              // App Tour
              const Text('App Tour', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Text('Need a refresher on how things work?', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              NeoButton(
                text: 'REPLAY TOUR',
                height: 40,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
