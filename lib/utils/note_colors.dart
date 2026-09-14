import 'package:flutter/material.dart';

class NoteColorDef {
  final String id;
  final Color bg;
  final Color border;
  final Color text;

  const NoteColorDef({
    required this.id,
    required this.bg,
    required this.border,
    required this.text,
  });
}

const List<NoteColorDef> noteColors = [
  NoteColorDef(id: 'Yellow', bg: Color(0xFFFDE047), border: Color(0xFFEAB308), text: Colors.black),
  NoteColorDef(id: 'Green', bg: Color(0xFFA2E676), border: Color(0xFF8BCC61), text: Colors.black),
  NoteColorDef(id: 'Pink', bg: Color(0xFFFF94D2), border: Color(0xFFE67CB9), text: Colors.black),
  NoteColorDef(id: 'Purple', bg: Color(0xFFC197FF), border: Color(0xFFA97DE6), text: Colors.black),
  NoteColorDef(id: 'Blue', bg: Color(0xFF6BD9FA), border: Color(0xFF55C3E6), text: Colors.black),
  NoteColorDef(id: 'Gray', bg: Color(0xFFE0E0E0), border: Color(0xFFC4C4C4), text: Colors.black),
  NoteColorDef(id: 'Charcoal', bg: Color(0xFF2E2E2E), border: Color(0xFF1C1C1C), text: Colors.white),
  NoteColorDef(id: 'Default', bg: Color(0xFFFDE047), border: Color(0xFFEAB308), text: Colors.black),
];

NoteColorDef getColorDef(String? colorId) {
  return noteColors.firstWhere(
    (c) => c.id == colorId,
    orElse: () => noteColors.firstWhere((c) => c.id == 'Yellow'),
  );
}
