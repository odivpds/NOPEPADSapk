import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:uuid/uuid.dart';

import '../models/note.dart';
import '../services/supabase_service.dart';
import '../utils/note_colors.dart';
import '../widgets/neo_interactive.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId;

  const NoteEditorScreen({super.key, this.noteId});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _quillController = quill.QuillController.basic();
  
  bool _isLoading = false;
  Note? _existingNote;
  String _selectedColorId = 'Yellow'; // Default

  @override
  void initState() {
    super.initState();
    if (widget.noteId != null) {
      _loadNote();
    }
  }

  Future<void> _loadNote() async {
    setState(() => _isLoading = true);
    final service = ref.read(notesServiceProvider);
    final note = await service.getNoteById(widget.noteId!);
    
    if (note != null) {
      _existingNote = note;
      _titleController.text = note.title;
      _selectedColorId = note.color;
      if (note.content != null && note.content != '') {
        try {
          final doc = quill.Document.fromJson(jsonDecode(note.content));
          _quillController.document = doc;
        } catch (e) {
          // Fallback if content is not valid Quill delta
          _quillController.document = quill.Document()..insert(0, note.content.toString());
        }
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNote() async {
    final service = ref.read(notesServiceProvider);
    final title = _titleController.text;
    final content = jsonEncode(_quillController.document.toDelta().toJson());

    if (_existingNote == null) {
      final newNote = Note(
        id: const Uuid().v4(),
        userId: service.userId,
        title: title,
        content: content,
        color: _selectedColorId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await service.createNote(newNote);
    } else {
      final updatedNote = _existingNote!.copyWith(
        title: title,
        content: content,
        color: _selectedColorId,
        updatedAt: DateTime.now(),
      );
      await service.updateNote(updatedNote);
    }
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteNote() async {
    final service = ref.read(notesServiceProvider);
    if (_existingNote != null) {
      await service.moveNoteToTrash(_existingNote!.id);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildTopBar(NoteColorDef colorDef) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorDef.bg,
        border: const Border(bottom: BorderSide(color: Colors.black, width: 4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          NeoInteractive(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.transparent, // Like ghost button
                borderRadius: BorderRadius.circular(0),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.black),
            ),
          ),
          Row(
            children: [
              // Color Picker
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedColorId,
                  icon: const Icon(Icons.palette, color: Colors.black),
                  dropdownColor: const Color(0xFF18181B),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => _selectedColorId = newValue);
                    }
                  },
                  items: noteColors.map<DropdownMenuItem<String>>((NoteColorDef c) {
                    return DropdownMenuItem<String>(
                      value: c.id,
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: c.bg,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(c.id),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8),
              if (_existingNote != null)
                NeoInteractive(
                  onTap: _deleteNote,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.delete, color: Colors.black),
                  ),
                ),
              NeoInteractive(
                onTap: _saveNote,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.check, color: Colors.black),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorDef = getColorDef(_selectedColorId);
    
    return Scaffold(
      backgroundColor: const Color(0xFF18181B), // Dark background for the whole editor
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopBar(colorDef),
                  
                  // Toolbar
                  Container(
                    color: Colors.black12,
                    padding: const EdgeInsets.all(8.0),
                    child: Theme(
                      data: ThemeData.dark(),
                      child: quill.QuillSimpleToolbar(
                        controller: _quillController,
                        config: const quill.QuillSimpleToolbarConfig(
                          showDividers: false,
                          showFontFamily: false,
                          showFontSize: false,
                          showInlineCode: false,
                          showSubscript: false,
                          showSuperscript: false,
                          showColorButton: false,
                          showBackgroundColorButton: false,
                          showClearFormat: false,
                          showAlignmentButtons: false,
                          showLeftAlignment: false,
                          showCenterAlignment: false,
                          showRightAlignment: false,
                          showJustifyAlignment: false,
                          showHeaderStyle: false,
                          showSearchButton: false,
                          showIndent: false,
                        ),
                      ),
                    ),
                  ),

                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: TextField(
                      controller: _titleController,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900, // Black
                        color: Colors.white,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Note Title',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  // Editor
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: DefaultTextStyle(
                        style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                        child: quill.QuillEditor.basic(
                          controller: _quillController,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
