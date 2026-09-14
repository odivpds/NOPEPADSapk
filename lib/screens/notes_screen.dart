import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/note.dart';
import '../services/supabase_service.dart';
import '../widgets/note_card.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/motivational_quote.dart';
import 'dart:async';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Note> _notes = [];
  bool _isLoading = true;
  String _userName = 'PRANA';
  String _appTitle = "PRANA'S NOPEPADS";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final name = user.userMetadata?['display_name'] ?? user.email?.split('@')[0] ?? 'EXPLORER';
      setState(() {
        _userName = name.toString().toUpperCase();
        _appTitle = "${_userName}'S NOPEPADS";
      });
    }

    try {
      final notes = await NotesService(Supabase.instance.client).getNotes();
      if (mounted) {
        setState(() {
          _notes = notes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _deleteNote(String id) async {
    try {
      await NotesService(Supabase.instance.client).moveNoteToTrash(id);
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _createNote() {
    Navigator.of(context).pushNamed('/editor').then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFF27272A),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF27272A),
              border: Border(bottom: BorderSide(color: Colors.black, width: 4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _appTitle,
                    style: GoogleFonts.pressStart2p(
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        letterSpacing: 2.0,
                        shadows: [Shadow(color: Colors.black, offset: Offset(3, 3))],
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Action Buttons
                _buildHeaderIcon(Icons.settings, () {
                  showDialog(context: context, builder: (_) => const SettingsDialog());
                }),
                const SizedBox(width: 8),
                _buildHeaderIcon(Icons.light_mode, () {}),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _createNote,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE047),
                      border: Border.all(color: Colors.black, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.add, color: Colors.black, size: 24),
                  ),
                ),
              ],
            ),
          ),

          // Main Body
          Expanded(
            child: Row(
              children: [
                // Left Column (Notes Grid)
                Container(
                  width: isDesktop ? 450 : MediaQuery.of(context).size.width,
                  color: const Color(0xFF18181B), // Darker sidebar bg
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search Bar
                      Row(
                        children: [
                          StatefulBuilder(builder: (context, setState) {
                            bool isHovered = false;
                            bool isPressed = false;
                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) => setState(() => isHovered = true),
                              onExit: (_) => setState(() => isHovered = false),
                              child: GestureDetector(
                                onTapDown: (_) => setState(() => isPressed = true),
                                onTapUp: (_) => setState(() => isPressed = false),
                                onTapCancel: () => setState(() => isPressed = false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 100),
                                  transform: (isHovered || isPressed) ? Matrix4.translationValues(4, 4, 0) : Matrix4.identity(),
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDE047),
                                    border: Border.all(color: Colors.black, width: 4),
                                    boxShadow: [BoxShadow(color: Colors.black, offset: (isHovered || isPressed) ? const Offset(0,0) : const Offset(4, 4))],
                                  ),
                                  child: const Icon(Icons.menu, color: Colors.black),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(width: 16),
                          Expanded(
                            child: StatefulBuilder(builder: (context, setState) {
                              bool isHovered = false;
                              return MouseRegion(
                                onEnter: (_) => setState(() => isHovered = true),
                                onExit: (_) => setState(() => isHovered = false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 100),
                                  transform: isHovered ? Matrix4.translationValues(2, 2, 0) : Matrix4.identity(),
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF18181B),
                                    border: Border.all(color: Colors.black, width: 4),
                                    boxShadow: [BoxShadow(color: Colors.black, offset: isHovered ? const Offset(2, 2) : const Offset(4, 4))],
                                  ),
                                  child: const TextField(
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.search, color: Colors.white54),
                                  hintText: 'Search notes...',
                                  hintStyle: TextStyle(color: Colors.white54),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Pinned Header
                      Container(
                        padding: const EdgeInsets.only(bottom: 12),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.black, width: 4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'PINNED',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                fontSize: 14,
                              ),
                            ),
                            StatefulBuilder(builder: (context, setState) {
                              bool isHovered = false;
                              return MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) => setState(() => isHovered = true),
                                onExit: (_) => setState(() => isHovered = false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 100),
                                  transform: isHovered ? Matrix4.translationValues(2, 2, 0) : Matrix4.identity(),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDE047),
                                    border: Border.all(color: Colors.black, width: 2),
                                    boxShadow: [BoxShadow(color: Colors.black, offset: isHovered ? const Offset(0, 0) : const Offset(2, 2))],
                                  ),
                                  child: const Text(
                                    'SELECT',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              );
                            })
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Grid
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFDE047)))
                            : _notes.isEmpty
                                ? const Center(child: Text('No notes yet. Create one!', style: TextStyle(color: Colors.white70)))
                                : ListView.builder(
                                    itemCount: _notes.length,
                                    itemBuilder: (context, index) {
                                      final note = _notes[index];
                                      return NoteCard(
                                        note: note,
                                        onTap: () {
                                          Navigator.of(context).pushNamed('/editor', arguments: note.id).then((_) => _loadData());
                                        },
                                        onDelete: () => _deleteNote(note.id),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
                // Right Column (Motivational Quote)
                if (isDesktop)
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: Colors.black, width: 4)),
                      ),
                      padding: const EdgeInsets.all(48.0),
                      child: Center(
                        child: MotivationalQuote(userName: _userName),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF27272A),
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}



